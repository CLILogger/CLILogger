//
//  main.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/6.
//

import Foundation
import ArgumentParser
import CocoaLumberjack

struct CLILogger: ParsableCommand {
    @Flag(help: "Show verbose logging or not.")
    var verbose = false

    @Option(name: .shortAndLong, help: "The service port number, defaults to automatic.")
    var port: Int?

    @Argument(help: "Service name.")
    var serviceName: String?

    mutating func run() throws {
        let portNumber = port ?? 0
        let name = serviceName ?? "default-name"

        print("\(portNumber): \(name)")
    }
}

CLILogger.main()
