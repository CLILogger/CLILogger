import Foundation
import CocoaLumberjack

@objcMembers
public class LoggingServiceInfo {
    public private(set) static var domain = "local."
    public private(set) static var type = "_cli-logging-server._tcp."

    public static var timeout: TimeInterval = 5

    public typealias InternalLogHandler = (DDLogLevel, String) -> Void
    public static var logHandler: InternalLogHandler?
}
