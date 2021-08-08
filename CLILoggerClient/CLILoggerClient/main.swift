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

#if false
let client = CLILoggingClient.shared

client.searchService()

client.log("This is \(Host.current().name ?? "a guest")")
client.log("See", "you", "next", "time!")
#else
DDLog.add(CLILogger.shared)

CLILoggingServiceInfo.logHandler = { level, message in
    print("[\(level)]: \(message)")
}

DDLogVerbose("Hello!")
DDLogDebug("This is \(Host.current().name ?? "a guest")")
DDLogInfo("The default internal log level is INFO")
DDLogWarn("Warn me if something wrong you encounter")
DDLogError("Remember to attach the error context verbosely")
#endif
RunLoop.main.run()

