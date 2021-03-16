//
//  LoggingClient.swift
//  CLILoggerClient
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack

@objcMembers
public class LoggingClient: NSObject {
    private var netServiceBrowser: NetServiceBrowser?
    private var allAvailableServices: [NetService] = []
    private var selectedServiceIndex: Int = 0 {
        didSet {
            selectService?.delegate = self
            selectService?.resolve(withTimeout: LoggingServiceInfo.timeout)
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
    private var pendingMessages: [LoggingEntity] = []
    private var dataQueue = DispatchQueue(label: "logging.serial.data.queue")

    public static var shared = LoggingClient()

    /// This method must be run in main thread because of NetServiceBrowser.
    public func searchService() {
        DispatchQueue.main.async {
            if let browser = self.netServiceBrowser {
                browser.stop()
            }

            self.netServiceBrowser = NetServiceBrowser()
            self.netServiceBrowser?.delegate = self
            self.netServiceBrowser?.searchForServices(ofType: LoggingServiceInfo.type, inDomain: LoggingServiceInfo.domain)
        }
    }

    public func log(_ args: String..., level: DDLogLevel = .debug, module: String? = nil) {
        log(args, level: level, module:module)
    }

    public func log(_ args: [String], level: DDLogLevel = .debug, module: String? = nil) {
        let msg = args.joined(separator: " ")
        log(entity: LoggingEntity(message: msg, level: level, module: module))
    }

    public func log(entity: LoggingEntity) {
        pendingMessages.append(entity)
    }

    private func connectToNextAddress() {
        var done = false

        while !done && serverAddresses.count > 0 {
            let address = serverAddresses.first!

            serverAddresses.removeFirst()

            do {
                try asyncSocket?.connect(toAddress: address, withTimeout: LoggingServiceInfo.timeout)
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
        // DDLogVerbose("dispatching...\(pendingMessages.count) message(s) pending.")

        if pendingMessages.isEmpty {
            return
        }

        guard let socket = asyncSocket, connected else {
            return
        }

        let entity = pendingMessages.first!

        writing = true
        socket.write(entity.bufferData, withTimeout: LoggingServiceInfo.timeout, tag: entity.tag)
    }

    private func resetCurrentService() {
        allAvailableServices.removeAll()
        selectedServiceIndex = 0
        serverAddresses.removeAll()
        asyncSocket = nil
    }

    private func askForChooseService(completion: (Int) -> Void) {
        print("\(#function)")

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
        assert(false, "implement not yet!")
        #endif
    }
}

extension LoggingClient: NetServiceBrowserDelegate {

    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("\(#function), found service \(service.name), has more: \(moreComing)")

        allAvailableServices.append(service)

        if !moreComing && !connected {
            askForChooseService { (index) in
                selectedServiceIndex = index
            }
        }
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("\(#function), error: \(errorDict)")
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("\(#function), service: \(service)")

        if service == selectService {
            resetCurrentService()
            connectToNextAddress()
        }
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("\(#function)")
    }
}

extension LoggingClient: NetServiceDelegate {

    public func netServiceDidResolveAddress(_ sender: NetService) {
        print("\(#function)")

        if serverAddresses.isEmpty {
            serverAddresses = sender.addresses!
        }

        if asyncSocket == nil {
            asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: dataQueue)
            connectToNextAddress()
        }
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print("\(#function), error: \(errorDict)")
        connectToNextAddress()
    }
}

extension LoggingClient: GCDAsyncSocketDelegate {

    public func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("\(#function), host: \(host), port: \(port)")
        connected = true
    }

    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("\(#function), error: \(err as Any)")
        connected = false
    }

    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if let index = pendingMessages.firstIndex(where: {$0.tag == tag}) {
            pendingMessages.remove(at: index)
        }

        writing = false
        dispatchPendingMessages()
    }
}
