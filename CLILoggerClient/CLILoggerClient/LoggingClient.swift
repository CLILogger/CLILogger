//
//  LoggingClient.swift
//  CLILoggerClient
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaAsyncSocket
import CocoaLumberjack
import CLILogger

class LoggingClient: NSObject {
    private var netServiceBrowser: NetServiceBrowser!
    private var serverService: NetService?
    private var serverAddresses: [Data] = []
    private var asyncSocket: GCDAsyncSocket?
    private var connected: Bool = false

    private var pendingMessages: [LoggingEntity] = []

    static var shared = LoggingClient()

    override init() {
        super.init()

        self.netServiceBrowser = NetServiceBrowser()
        self.netServiceBrowser.delegate = self
        self.netServiceBrowser.searchForServices(ofType: LoggingServiceInfo.type, inDomain: LoggingServiceInfo.domain)
    }

    private func connectToNextAddress() {
        var done = false

        while !done && serverAddresses.count > 0 {
            let address = serverAddresses.first!

            serverAddresses.removeFirst()

            do {
                try asyncSocket?.connect(toAddress: address)
                done = true
            } catch let error {
                DDLogError("Unable to connect with error: \(error)")
                done = false
            }
        }

        if !done {
            DDLogWarn("Unable to connect to any resolved address")
        }
    }

    private func dispatchPendingMessages() {
        if pendingMessages.isEmpty {
            return
        }

        guard let socket = asyncSocket, connected else {
            return
        }

        let entity = pendingMessages.first!
        socket.write(entity.bufferData, withTimeout: 5, tag: entity.tag)
    }
}

extension LoggingClient: NetServiceBrowserDelegate {

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        DDLogVerbose("\(#function)")

        if serverService == nil {
            DDLogInfo("Resolving service \(service)...")

            serverService = service
            serverService?.delegate = self
            serverService?.resolve(withTimeout: 5)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        DDLogError("\(#function), error: \(errorDict)")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        DDLogInfo("\(#function), service: \(service)")
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        DDLogInfo("\(#function)")
    }
}

extension LoggingClient: NetServiceDelegate {

    func netServiceDidResolveAddress(_ sender: NetService) {
        DDLogDebug("\(#function)")

        if serverAddresses.isEmpty {
            serverAddresses = sender.addresses!
        }

        if asyncSocket == nil {
            asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
            connectToNextAddress()
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        DDLogError("\(#function), error: \(errorDict)")
    }
}

extension LoggingClient: GCDAsyncSocketDelegate {

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        DDLogInfo("\(#function), host: \(host), port: \(port)")
        connected = true
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        DDLogInfo("\(#function), error: \(err as Any)")

        if !connected {
            connectToNextAddress()
        }
    }

    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        if let index = pendingMessages.firstIndex(where: {$0.tag == tag}) {
            pendingMessages.remove(at: index)
            DDLogVerbose("Write data \(tag) successfully!")
        }

        dispatchPendingMessages()
    }
}
