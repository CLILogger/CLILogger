//
//  main.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/6.
//

import Foundation
import ArgumentParser
import CocoaLumberjack
import CLILogger

if (ProcessInfo().environment["TERM"] != nil) {
    // Terminal
    DDLog.add(DDTTYLogger.sharedInstance!)
} else {
    // Xcode Console
    DDLog.add(DDOSLogger.sharedInstance)
}

var config = Configuration()

if !config.load(from: Configuration.defaultConfigFile) {
    config.addModule(klass: LoggingService.self, mode: .blocklist)
    config.saveToDefaultFileIfNecessary()
}

struct CLILogger: ParsableCommand {
    @Flag(help: "Show verbose logging or not.")
    var verbose = false

    @Argument(help: "Service name.")
    var serviceName: String?

    @Option(name: .shortAndLong, help: "The service port number, defaults to automatic.")
    var port: UInt16?

    mutating func run() throws {
        DDLog.setLevel(verbose ? .verbose : .info, for: LoggingService.self)

        LoggingServiceInfo.logHandler = { level, message in
            switch level {
            case .error:
                DDLogError(message)
                break

            case .warning:
                DDLogWarn(message)
                break

            case .info:
                DDLogInfo(message)
                break

            case .debug:
                DDLogDebug(message)
                break

            case .verbose:
                DDLogVerbose(message)
                break

            default:
                break
            }
        }

        let service = LoggingService.shared

        if let name = serviceName {
            service.serviceName = name
        } else if let configName = config.serviceName {
            service.serviceName = configName
        }

        if let p = port {
            service.port = p
        } else if let configPort = config.servicePort {
            service.port = configPort
        }

        service.publish()
    }
}

CLILogger.main()

RunLoop.current.run()
