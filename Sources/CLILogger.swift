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
        client.log(logMessage.message, flag: logMessage.flag, module: logMessage.file)
    }
}
