import Foundation
import CocoaLumberjack

@objcMembers
public class CLILoggingServiceInfo {
    public private(set) static var domain = "local."
    public private(set) static var type = "_cli-logger-server._tcp."

    public static var timeout: TimeInterval = 5

    public typealias InternalLogHandler = (DDLogLevel, String) -> Void
    public static var logHandler: InternalLogHandler?
}
