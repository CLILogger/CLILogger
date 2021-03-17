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
import RainbowSwift

class CLILoggingService: NSObject {
    public static let shared = CLILoggingService()
    public var serviceName: String = Host.current().name ?? "CLI Logging Service"
    public var port: UInt16 = 0

    private var netService: NetService!
    private var asyncSocket: GCDAsyncSocket!
    private var connectedSockets: [GCDAsyncSocket] = []

    private var timer: DispatchSourceTimer?
    private var reading: Bool = false
    private var dataQueue = DispatchQueue(label: "clilogger.service.serial.data.queue")

    override private init() {
        super.init()
        self.asyncSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)

        timer = DispatchSource.makeTimerSource(queue: dataQueue)

        timer?.setEventHandler { [unowned self] in
            if self.reading && self.connectedSockets.count <= 0 {
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

            port = asyncSocket.localPort

            netService = NetService(domain: CLILoggingServiceInfo.domain, type: CLILoggingServiceInfo.type, name: serviceName, port: Int32(port))
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
        // Save the incoming host name as its alias in its lifecycle.
        newSocket.name = newSocket.connectedHost ?? "Unknown"

        DDLogInfo("\(newSocket.name!) connected!")
        connectedSockets.append(newSocket)
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        DDLogInfo("\(sock.name!) disconnected!")
        connectedSockets.removeAll { (socket) -> Bool in
            sock == socket
        }
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        DDLogVerbose("\(#function)")

        let endIndex = data.endIndex - Data.terminator.endIndex + 1
        let validData = data.subdata(in: 0..<data.index(before: endIndex))
        let entity = CLILoggingEntity(data: validData)

        print(entity.prettyFormatMessage())
    }
}

extension GCDAsyncSocket {

    // Bind the name info to `userData`.
    fileprivate var name: String? {
        get { return userData as? String }
        set { userData = newValue }
    }
}

extension CLILoggingEntity {
    static var formatter: DateFormatter {
        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    public func prettyFormatMessage() -> String {
        var result = Self.formatter.string(from: date)
        var strLevel = ""
        var color = Color.default

        switch flag! {
        case .error:
            strLevel = "ERROR"
            color = .red
            break

        case .warning:
            strLevel = "WARNING"
            color = .yellow
            break

        case .info:
            strLevel = "INFO"
            color = .lightWhite
            break

        case .debug:
            strLevel = "DEBUG"
            color = .green
            break

        case .verbose:
            strLevel = "VERBOSE"
            color = .black
            break

        default:
            break
        }

        result += " \(strLevel.padding(toLength: 8, withPad: " ", startingAt: 0))"

        if let mod = module {
            result += " \(mod)"
        }

        result += " \(message!)"
        return result.applyingColor(color)
    }
}
