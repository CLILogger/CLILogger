//
//  main.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/6.
//

import Foundation
import ArgumentParser
import CocoaLumberjack

if (ProcessInfo().environment["TERM"] != nil) {
    // Terminal
    DDLog.add(DDTTYLogger.sharedInstance!)
} else {
    // Xcode Console
    DDLog.add(DDOSLogger.sharedInstance)
}


struct CLILogger: ParsableCommand {
    @Flag(help: "Show verbose logging or not.")
    var verbose = false

    @Argument(help: "Service name.")
    var serviceName: String?

    @Option(name: .shortAndLong, help: "The service port number, defaults to automatic.")
    var port: UInt16?

    mutating func run() throws {
        DDLog.setLevel(verbose ? .verbose : .verbose, for: LoggingService.self)

        let service = LoggingService.shared

        if let name = serviceName {
            service.serviceName = name
        }

        if let p = port {
            service.port = p
        }

        service.publish()
    }
}

CLILogger.main()

RunLoop.current.run()
