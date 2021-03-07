//
//  main.swift
//  CLILoggerClient
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaLumberjackSwift

if (ProcessInfo().environment["TERM"] != nil) {
    // Terminal
    DDLog.add(DDTTYLogger.sharedInstance!)
} else {
    // Xcode Console
    DDLog.add(DDOSLogger.sharedInstance)
}


DDLogInfo("Hello, World!")


