//
//  LoggingService.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack
import CLILogger

class CLILoggingService: NSObject {
    public var serviceName: String?
    public var port: UInt16 = 0

    // Incoming identity handler
    public var foundIncomingIdentity: ((CLILoggingIdentity) -> Bool)?
    // Incoming message handler
    public var foundIncomingMessage: ((CLILoggingEntity) -> Void)?
    public var resolveDeviceName: ((CLILoggingEntity) -> String)?

    // Service and sockets info.
    private var netService: NetService!
    private var asyncSocket: GCDAsyncSocket!
    private var connectedSockets: [GCDAsyncSocket] = []

    public var connectedSocketCount: Int {
        connectedSockets.filter({ $0.identified }).count
    }

    // Read the incoming message entities repeatly.
    private var timer: DispatchSourceTimer?
    private var reading: Bool = false
    private var dataQueue = DispatchQueue(label: "clilogger.service.serial.data.queue")

    public override init() {
        super.init()
        self.asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)

        setupTimer()
    }

    deinit {
        netService.stop()
        netService = nil
        asyncSocket.disconnect()
        asyncSocket = nil
        connectedSockets.removeAll()
        timer?.cancel()
        timer = nil
    }

    public func publish() {
        do {
            try asyncSocket.accept(onPort: port)

            serviceName = serviceName ?? Host.current().name ?? "CLI Logging Service"
            port = asyncSocket.localPort

            netService = NetService(domain: CLILoggingServiceInfo.domain, type: CLILoggingServiceInfo.type, name: serviceName!, port: Int32(port))
            netService.delegate = self
            netService.publish()

            let txtInfo: [String: Data?] = [
                "name": Host.current().name?.data(using: .utf8),
                "user": NSUserName().data(using: .utf8),
                "build": "0.1".data(using: .utf8),
            ]
            let data = NetService.data(fromTXTRecord: txtInfo as! [String: Data])
            netService.setTXTRecord(data)
        } catch let err {
            DDLogError("error: \(err)")
        }
    }

    private func setupTimer() {
        timer = DispatchSource.makeTimerSource(queue: dataQueue)

        timer?.setEventHandler { [unowned self] in
            if self.reading || self.connectedSockets.count <= 0 {
                return
            }

            self.reading = true
            for socket in self.connectedSockets {
                // timeout -1 means waits forever, any other explict positive values
                // will make the socket get disconnected after timeout.
                socket.readData(to: Data.terminator, withTimeout: -1, tag: 0)
            }
            self.reading = false
        }

        timer?.schedule(deadline: .now(), repeating: .milliseconds(1), leeway: .microseconds(500))
        timer?.resume()
    }

    private func log(level: DDLogLevel, activity: String) {
        guard let handler = CLILoggingServiceInfo.logHandler else {
            return
        }

        handler(level, activity)
    }
}

extension CLILoggingService: NetServiceDelegate {

    func netServiceDidPublish(_ sender: NetService) {
        DDLogVerbose("\(#function)")
        DDLogInfo("Publish service \(sender.name) on port \(sender.port), info: type=\(sender.type) domain=\(sender.domain)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        DDLogVerbose("\(#function), error: \(errorDict)")
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        DDLogVerbose("\(#function), error: \(errorDict)")
    }
}

extension CLILoggingService: GCDAsyncSocketDelegate {

    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        DDLogVerbose("\(newSocket.connectedHost ?? "Unknown") accepted!")
        connectedSockets.append(newSocket)
    }

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        DDLogVerbose("\(sock.connectedHost ?? "Unknown") connected!")
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        DDLogInfo("Bye! \(sock.identity?.hostName ?? "Unknown")")
        connectedSockets.removeAll { $0 == sock }
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        DDLogVerbose("\(#function)")

        let typeEndIndex = data.startIndex + Int(Data.MessageType.length)
        let typeData = data.subdata(in: 0..<typeEndIndex)
        let type = Data.MessageType.match(typeData)

        let endIndex = data.endIndex - Data.terminator.endIndex + 1
        let messageData = data.subdata(in: typeEndIndex..<data.index(before: endIndex))

        switch type {
        case .hello:
            var identity = CLILoggingIdentity(data: messageData)

            if let device = config.deviceAliases?.first(where: { $0.identifier == identity.deviceID }),
               let alias = device.alias {
                DDLogVerbose("Renaming device \(identity.hostName)[\(identity.deviceID)] to \(alias)")
                identity.rename(to: alias)
            }

            if let handler = foundIncomingIdentity, !handler(identity) {
                DDLogVerbose("Disconnecting the socket \(sock)")
                sock.delegate = nil
                sock.disconnect()
            } else {
                sock.identity = identity
            }
            break

        case .entity:
            let entity = CLILoggingEntity(data: messageData)

            assert(sock.identity != nil, "Didn't find the identity of current socket!")
            entity.identity = sock.identity

            if let resolver = resolveDeviceName {
                entity.deviceName = resolver(entity)
            }

            if let handler = foundIncomingMessage {
                handler(entity)
            }
            break

        default:
            DDLogError("Found unexpected data message: \(data)")
            break
        }
    }
}

extension GCDAsyncSocket {

    var identity: CLILoggingIdentity? {
        get { self.userData as! CLILoggingIdentity? }
        set { self.userData = newValue }
    }

    var identified: Bool {
        identity != nil
    }
}
