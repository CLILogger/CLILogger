//
//  CLILoggingClient.swift
//  CLILoggerClient
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack

#if os(macOS)
    #if canImport(AppKit) // macOS GUI application
        import AppKit
    #endif
#elseif os(iOS)
    import UIKit
    let lastUsedLoggingServiceID = "cli-logger.last_used_logging_service"
#endif

// MARK: - CLILoggingClient

@objcMembers
public class CLILoggingClient: NSObject {
    private var netServiceBrowser: NetServiceBrowser?
    private var allAvailableServices: [NetService] = []
    private var selectedServiceIndex: Int = 0 {
        didSet {
            selectService?.delegate = self
            selectService?.resolve(withTimeout: CLILoggingServiceInfo.timeout)
        }
    }
    private var selectService: NetService? {
        guard selectedServiceIndex >= 0, allAvailableServices.count > 0 else {
            return nil
        }
        return allAvailableServices[selectedServiceIndex]
    }
    private var serverAddresses: [Data] = []
    private var asyncSocket: GCDAsyncSocket?
    public private(set) var connected: Bool = false {
        didSet {
            if connected {
                dispatchPendingMessages()
            } else {
                resetCurrentService()
                searchService()
            }
        }
    }
    private var writing: Bool = false
    private var pendingMessages: [CLILoggingEntity] = []
    private var queueLocker: NSRecursiveLock = .init()
    private var dataQueue = DispatchQueue(label: "clilogger.client.serial.data.queue")

    public static var shared = CLILoggingClient()

    public func searchService() {
        // This method must be run in main thread because of NetServiceBrowser.
        DispatchQueue.main.async {
            self.stopService()
            self.netServiceBrowser = NetServiceBrowser()
            self.netServiceBrowser?.delegate = self
            self.netServiceBrowser?.searchForServices(ofType: CLILoggingServiceInfo.type, inDomain: CLILoggingServiceInfo.domain)
        }
    }

    public func stopService() {
        if let browser = self.netServiceBrowser {
            browser.stop()
        }
    }

    public func log(_ args: String..., flag: DDLogFlag = .verbose, filename: String? = nil, line: UInt? = nil, function: String? = nil) {
        log(args, flag: flag, filename: filename, line: line, function: function)
    }

    public func log(_ args: [String], flag: DDLogFlag = .verbose, filename: String? = nil, line: UInt? = nil, function: String? = nil) {
        let msg = args.joined(separator: " ")
        log(entity: CLILoggingEntity(message: msg, flag: flag, filename: filename, line: line, function: function))
    }

    public func log(entity: CLILoggingEntity) {
        queueLocker.lock()
        pendingMessages.append(entity)
        queueLocker.unlock()

        dispatchPendingMessages()
    }

    private func log(_ level: DDLogLevel, activity: String) {
        guard let handler = CLILoggingServiceInfo.logHandler else {
            return
        }

        handler(level, activity)
    }

    private func connectToNextAddress() {
        var done = false

        while !done && serverAddresses.count > 0 {
            let address = serverAddresses.first!

            serverAddresses.removeFirst()

            do {
                try asyncSocket?.connect(toAddress: address, withTimeout: CLILoggingServiceInfo.timeout)
                done = true
            } catch let error {
                print("Unable to connect with error: \(error)")
                done = false
            }
        }

        if !done {
            print("Unable to connect to any resolved addresses!")
            resetCurrentService()
            searchService()
        }
    }

    private func dispatchPendingMessages() {
        guard let socket = asyncSocket, connected else {
            return
        }

        queueLocker.lock()

        if pendingMessages.isEmpty || writing {
            queueLocker.unlock()
            return
        }

        writing = true
        log(.verbose, activity: "dispatching...\(pendingMessages.count) message(s) pending.")

        let entity = pendingMessages.first!

        queueLocker.unlock()

        var data = entity.bufferData

        data.append(Data.terminator)
        socket.write(data, withTimeout: CLILoggingServiceInfo.timeout, tag: entity.tag)
    }

    private func resetCurrentService() {
        log(.verbose, activity: "Resetting service...")

        allAvailableServices.removeAll()
        selectedServiceIndex = 0
        serverAddresses.removeAll()
        asyncSocket = nil
    }

    private func askForChooseService(completion: @escaping (Int) -> Void) {
        log(.verbose, activity: "\(#function)")

        let count = allAvailableServices.count

        if count <= 1 {
            if count <= 0 {
                completion(NSNotFound)
            } else {
                completion(0)
            }

            return
        }

        #if os(macOS)
        print("Found \(count) available services, choose one:")

        while true {
            for (index, service) in allAvailableServices.enumerated() {
                print("\(index): \(service.name)")
            }

            guard let input = readLine(), let choose = Int(input), 0 <= choose && choose < count else {
                print("Invalid input, type corresponding index again.")
                continue
            }

            completion(choose)
            break
        }
        #elseif os(iOS)
        let lastUsedServiceID = UserDefaults.standard.value(forKey: lastUsedLoggingServiceID)

        if lastUsedServiceID != nil {
            let service_id = allAvailableServices.firstIndex { $0.name == lastUsedServiceID as! String }

            if service_id != NSNotFound {
                completion(service_id!)
                print("Using the last used service: \(lastUsedServiceID!)")
                return
            }
        }

        let rootVC = UIApplication.shared.keyWindow?.rootViewController
        let alertVC = UIAlertController.init(title: "Choose your logging service", message: "Found multiple service around you, feel free to remember it.", preferredStyle: .alert)
        let new_action: (NetService, Int, Bool) -> UIAlertAction = { service, index, remember in
            let title = "\(service.name) \(remember ? "(use it always)" : "(only this time)")"
            return UIAlertAction.init(title: title, style: .default, handler: { _ in
                if remember {
                    UserDefaults.standard.set(service.name, forKey: lastUsedLoggingServiceID)
                }

                completion(index)
            })
        }

        for (index, service) in allAvailableServices.enumerated() {
            alertVC.addAction(new_action(service, index, false))
            alertVC.addAction(new_action(service, index, true))
        }

        alertVC.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))

        rootVC?.present(alertVC, animated: true, completion: nil)
        #endif
    }
}

// MARK: - NetServiceBrowserDelegate

extension CLILoggingClient: NetServiceBrowserDelegate {

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        log(.verbose, activity: "\(#function), found service \(service.name), has more: \(moreComing)")

        allAvailableServices.append(service)

        if !moreComing && !connected {
            askForChooseService { (index) in
                self.selectedServiceIndex = index
            }
        }
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        log(.info, activity: "\(#function), error: \(errorDict)")
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        log(.info, activity: "\(#function), service: \(service)")

        if let index = allAvailableServices.firstIndex(of: service) {
            allAvailableServices.remove(at: index)
        }

        if service == selectService {
            resetCurrentService()
            connectToNextAddress()
        }
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        log(.info, activity: "\(#function)")
    }
}

// MARK: - NetServiceDelegate

extension CLILoggingClient: NetServiceDelegate {

    public func netServiceDidResolveAddress(_ sender: NetService) {
        log(.info, activity: "\(#function)")

        if serverAddresses.isEmpty {
            serverAddresses = sender.addresses!
        }

        if asyncSocket == nil {
            asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: dataQueue)
            connectToNextAddress()
        }
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        log(.warning, activity: "\(#function), error: \(errorDict)")
        connectToNextAddress()
    }
}

// MARK: - GCDAsyncSocketDelegate

extension CLILoggingClient: GCDAsyncSocketDelegate {

    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        log(.verbose, activity: "\(#function), host: \(host), port: \(port)")
        connected = true
    }

    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        log(.warning, activity: "\(#function), error: \(err as Any)")
        connected = false
    }

    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        queueLocker.lock()

        if let index = pendingMessages.firstIndex(where: {$0.tag == tag}) {
            pendingMessages.remove(at: index)
        }

        writing = false
        queueLocker.unlock()
        dispatchPendingMessages()
    }
}
