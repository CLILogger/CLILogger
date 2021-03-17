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

var config = Configuration()

if !config.load(from: Configuration.defaultConfigFile) {
    config.addModule(klass: CLILoggingService.self, mode: .blocklist)
    config.saveToDefaultFileIfNecessary()
}

func SetupInternalLogger(level: DDLogLevel) {
    if (ProcessInfo().environment["TERM"] != nil) {
        // Terminal
        DDLog.add(DDTTYLogger.sharedInstance!, with: level)
    } else {
        // Xcode Console
        DDLog.add(DDOSLogger.sharedInstance, with: level)
    }
}

struct CLILogger: ParsableCommand {
    @Flag(help: "Show verbose logging of internal service or not.")
    var verbose = false

    @Argument(help: "Service name.")
    var serviceName: String?

    @Option(name: .shortAndLong, help: "The service port number, defaults to automatic.")
    var port: UInt16?

    mutating func run() throws {
        SetupInternalLogger(level: verbose ? .verbose : .info)

        let service = CLILoggingService.shared

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
