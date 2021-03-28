//
//  main.swift
//  CLILoggerClient
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaLumberjack
import CLILogger

if (ProcessInfo().environment["TERM"] != nil) {
    // Terminal
    DDLog.add(DDTTYLogger.sharedInstance!)
} else {
    // Xcode Console
    DDLog.add(DDOSLogger.sharedInstance)
}

let client = CLILoggingClient.shared

client.searchService()

client.log("This is \(Host.current().name ?? "a guest")")
client.log("See", "you", "next", "time!")

RunLoop.main.run()
