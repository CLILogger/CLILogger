//
//  CLILoggingClient.swift
//  CLILogger
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
            selectedService?.delegate = self
            selectedService?.resolve(withTimeout: CLILoggingServiceInfo.timeout)
        }
    }
    private var selectedService: NetService? {
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
                sendIdentifyMessage()
            } else {
                resetCurrentService()
                searchService()
            }
        }
    }
    private var writing: Bool = false
    private var identityMessage: CLILoggingIdentity = .init()
    private var identityApproved: Bool = false {
        didSet {
            if identityApproved {
                dispatchPendingMessages()
            } else {
                // When identify get rejected, the socket will be disconnected, too.
                // Do nothing here.
            }
        }
    }
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

    /// Try to connect the resolved server addresses one by one.
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

        if !done && !connected {
            print("Unable to connect to any resolved addresses!")
            resetCurrentService()
            searchService()
        }
    }

    /// Send the client's identity to server before using it.
    private func sendIdentifyMessage() {
        guard let socket = asyncSocket, connected else {
            return
        }

        var data = Data.MessageType.hello.data

        data.append(identityMessage.bufferData)
        data.append(Data.terminator)
        socket.write(data, withTimeout: CLILoggingServiceInfo.timeout, tag: CLILoggingIdentity.initialTag)
    }

    /// Pick first message from the pending message queue and send it.
    private func dispatchPendingMessages() {
        guard let socket = asyncSocket, connected, identityApproved else {
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

        var data = Data.MessageType.entity.data

        data.append(entity.bufferData)
        data.append(Data.terminator)
        socket.write(data, withTimeout: CLILoggingServiceInfo.timeout, tag: entity.tag!)
    }

    /// Reset the net service, index, addresses and socket.
    private func resetCurrentService() {
        log(.verbose, activity: "Resetting service...")

        selectedService?.delegate = nil
        allAvailableServices.removeAll()
        serverAddresses.removeAll()
        selectedServiceIndex = 0
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

        if service == selectedService {
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
        log(.info, activity: "\(#function), sender: \(sender)")

        if serverAddresses.isEmpty {
            serverAddresses = sender.addresses!.filter { !CLILoggingRecord.allRejectedAddresses.contains($0) }
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
        CLILoggingRecord.save(sock)
        connected = true
    }

    public func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        log(.warning, activity: "\(#function), error: \(err as Any)")

        if let error = err as NSError?, error.domain == GCDAsyncSocketErrorDomain,
           GCDAsyncSocketError.Code(rawValue: error.code) == GCDAsyncSocketError.closedError {
            log(.info, activity: "Rejected socket \(sock)")

            CLILoggingRecord.reject(sock)
            identityApproved = false
        }

        connected = false
    }

    public func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        log(.verbose, activity: "\(#function), tag: \(tag)")
        let (type, messageData) = data.extracted()

        switch type {
        case .reject:
            let response = CLILoggingResponse(data: messageData!)

            if let result = response.accepted, result == true {
                log(.info, activity: "The socket identity get accepted!")
                identityApproved = true
            } else {
                log(.warning, activity: "The socket identity get rejected! Message: \(response.message ?? "none")")
            }
            break

        default:
            DDLogError("Found unexpected data message: \(data)")
            break
        }
    }

    public func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if CLILoggingIdentity.tagRange.contains(tag) {
            // Sent the 'hello' message already, let's wait for server response.
            sock.readData(to: Data.terminator, withTimeout: -1, tag: CLILoggingResponse.initialTag)
            return
        }

        guard CLILoggingEntity.tagRange.contains(tag), let index = pendingMessages.firstIndex(where: {$0.tag == tag}) else {
            return
        }

        queueLocker.lock()
        pendingMessages.remove(at: index)
        writing = false
        queueLocker.unlock()

        dispatchPendingMessages()
    }
}

// MARK: - Data

public extension Data {

    enum MessageType : String, CaseIterable {
        case hello = "HI"
        case reject = "RJ"
        case entity = "EN"

        public static var length: UInt8 {
            2
        }

        public static func match(_ data: Data) -> MessageType? {
            MessageType.allCases.first { $0.data == data }
        }

        public var data: Data {
            self.rawValue.data(using: .utf8)!
        }
    }

    static var terminator: Data {
        get {
            // https://stackoverflow.com/a/24850996/1677041
            let bytes = [0x1F, 0x20, 0x20, 0x1F]
            return Data(bytes: bytes, count: bytes.count)
        }
    }

    func extracted() -> (MessageType?, Data?) {
        let typeEndIndex = self.startIndex + Int(Data.MessageType.length)
        let typeData = self.subdata(in: 0..<typeEndIndex)
        let type = Data.MessageType.match(typeData)

        let endIndex = self.endIndex - Data.terminator.endIndex + 1
        let messageData = self.subdata(in: typeEndIndex..<self.index(before: endIndex))

        return (type, messageData)
    }
}

// MARK: - CLILoggingRecord

fileprivate class CLILoggingRecord: Equatable {
    var address: Data
    weak var socket: GCDAsyncSocket?
    var rejected: Bool = false

    static var allRecords: [CLILoggingRecord] = []

    init(_ address: Data, socket: GCDAsyncSocket) {
        self.address = address
        self.socket = socket
    }

    static func == (lhs: CLILoggingRecord, rhs: CLILoggingRecord) -> Bool {
        lhs.address == rhs.address
    }

    static func save(_ socket: GCDAsyncSocket) {
        let record = CLILoggingRecord(socket.connectedAddress!, socket: socket)

        if !allRecords.contains(record) {
            allRecords.append(record)
        }
    }

    static func reject(_ socket: GCDAsyncSocket) {
        let record = allRecords.first { $0.socket == socket }

        assert(record != nil, "Rejecting a non-exist socket record!")
        record?.rejected = true
    }

    static var allRejectedAddresses: [Data] {
        allRecords.filter({ $0.rejected }).map { $0.address }
    }
}
