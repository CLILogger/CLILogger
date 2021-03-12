import Foundation

public struct LoggingServiceInfo {
    public private(set) static var domain = "local."
    public private(set) static var type = "_cli-logging-server._tcp."

    public static var timeout: TimeInterval = 5
}
