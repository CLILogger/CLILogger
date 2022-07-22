//
//  main.swift
//  CLILoggerClient
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaLumberjack
import CLILogger

func SetupInternalLogger() {
    if (ProcessInfo().environment["TERM"] != nil) {
        // Terminal
        DDLog.add(DDTTYLogger.sharedInstance!)
    } else {
        // Xcode Console
        DDLog.add(DDOSLogger.sharedInstance)
    }

    CLILoggingServiceInfo.logHandler = { level, message in
        // print("[\(level)]: \(message)")
    }
}

func TrySimpleHello() {
    let client = CLILoggingClient.shared

    client.searchService()

    client.log("This is \(Host.current().name ?? "a guest")")
    client.log("See", "you", "next", "time!")
}

func TryLevelMessage() {
    DDLog.add(CLILogger.shared)

    DDLogVerbose("Hello!")
    DDLogDebug("This is \(Host.current().name ?? "a guest")")
    DDLogInfo("The default internal log level is INFO")
    DDLogWarn("Warn me if something wrong you encounter")
    DDLogError("Remember to attach the error context verbosely")
}

func TryLevelMessageLoop() {
    DDLog.add(CLILogger.shared)

    DispatchQueue.global().async {
        var counter: Int = 0

        while true {
            DDLogVerbose("Hello! \(counter)")
            DDLogDebug("This is \(Host.current().name ?? "a guest")")
            DDLogInfo("The default internal log level is INFO")
            DDLogWarn("Warn me if something wrong you encounter")
            DDLogError("Remember to attach the error context verbosely")

            counter += 1
            sleep(3)
        }
    }
}

SetupInternalLogger()

switch CommandLine.arguments.last {
case "level":
    TryLevelMessage()
case "loop":
    TryLevelMessageLoop()
default:
    TrySimpleHello()
}

RunLoop.main.run()

