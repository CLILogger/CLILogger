//
//  CLILogger.swift
//  CLILogger
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaLumberjack

@objcMembers
public class CLILoggingServiceInfo: NSObject {
    public private(set) static var domain = "local."
    public private(set) static var type = "_cli-logger-server._tcp."

    public static var timeout: TimeInterval = 5

    public typealias InternalLogHandler = (DDLogLevel, String) -> Void
    public static var logHandler: InternalLogHandler?
}

@objcMembers
public class CLILogger: NSObject, DDLogger {

    @objc(sharedInstance)
    public private(set) static var shared = CLILogger()
    public var logFormatter: DDLogFormatter?
    private var client: CLILoggingClient!

    override private init() {
        super.init()

        client = CLILoggingClient()
        client.searchService()
    }

    public func log(message logMessage: DDLogMessage) {
        client.log(logMessage.message, flag: logMessage.flag, filename: logMessage.fileName, line: logMessage.line, function: logMessage.function)
    }
}

protocol CLILoggingProtocol {
    static var initialTag: Int { get }
    static var tagRange: Range<Int> { get }
    
    var bufferData: Data { get }
    var tag: Int { get }
    var isValid: Bool { get }
    
    init(data: Data)
}
