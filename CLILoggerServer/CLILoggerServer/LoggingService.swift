//
//  LoggingService.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack

class LoggingService: NSObject {
    private var netService: NetService!
    private var asyncSocket: GCDAsyncSocket!
    private var connectedSockets: [GCDAsyncSocket] = []

    static let shared = LoggingService()
    var serviceName: String = {
        Host.current().name ?? "CLI Logging Service"
    }()
    var port: UInt16 = 0

    override init() {
        super.init()
        self.asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
    }

    func publish() {
        do {
            try asyncSocket.accept(onPort: port)

            port = asyncSocket.localPort

            netService = NetService(domain: LoggingServiceInfo.domain, type: LoggingServiceInfo.type, name: serviceName, port: Int32(port))
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

    private func readDataFromClients() {
        for socket in connectedSockets {
            socket.readData(to: Data.terminator, withTimeout: -1, tag: 0)
        }
    }
}

extension LoggingService: NetServiceDelegate {

    func netServiceDidPublish(_ sender: NetService) {
        DDLogInfo("\(#function)")
        DDLogInfo("Publish service '\(sender.name)' on port \(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        DDLogWarn("\(#function)")
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        DDLogWarn("\(#function)")
    }
}

extension LoggingService: GCDAsyncSocketDelegate {

    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        DDLogInfo("\(#function)")
        connectedSockets.append(newSocket)
        readDataFromClients()
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        DDLogError("\(#function)")
        connectedSockets.removeAll { (socket) -> Bool in
            sock == socket
        }
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        DDLogInfo("\(#function)")

        let endIndex = data.endIndex - Data.terminator.endIndex
        let validData = data.subdata(in: 0..<data.index(before: endIndex))
        let entity = LoggingEntity(data: validData)

        DDLogDebug("entity: \(entity)")
        readDataFromClients()
    }
}

