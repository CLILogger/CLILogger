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
    public var foundIncomingIdentity: ((CLILoggingIdentity) -> (Bool, String?))?
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
        self.asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: .main)

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
        let (type, messageData) = data.extract()

        guard let messageData = messageData else {
            DDLogWarn("Invalid message data extracted, tag: \(tag)")
            return
        }

        switch type {
        case .hello:
            var identity = CLILoggingIdentity(data: messageData)

            if let device = config.deviceAliases?.first(where: { $0.identifier == identity.deviceID }),
               let alias = device.alias {
                DDLogVerbose("Renaming device \(identity.hostName)[\(identity.deviceID)] to \(alias)")
                identity.rename(to: alias)
            }

            var response: CLILoggingResponse!

            if let handler = foundIncomingIdentity {
                let result = handler(identity)
                response = CLILoggingResponse(accept: result.0, message: result.1, type: .hello)
            } else {
                response = CLILoggingResponse(accept: true, message: nil, type: .hello)
            }

            if response.accepted == true {
                // Only the accepted sockets have identity.
                sock.identity = identity
            }

            sock.write(response.bufferData.wrap(as: .ack), withTimeout: -1, tag: CLILoggingResponse.initialTag)

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

            let response = CLILoggingResponse(accept: true, message: nil, type: .entity, tag: entity.tag)
            sock.write(response.bufferData.wrap(as: .ack), withTimeout: -1, tag: 0)

        default:
            DDLogError("Found unexpected data message: \(data)")
        }
    }

    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if (tag == CLILoggingResponse.initialTag) {
            if sock.identity == nil {
                DDLogVerbose("Disconnecting the socket \(sock)")
                sock.delegate = nil
                sock.disconnect()
            }

            return
        }

        DDLogVerbose("\(#function) Found unexpected writing data with tag: \(tag)")
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
