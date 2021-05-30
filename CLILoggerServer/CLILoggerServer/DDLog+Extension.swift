//
//  DDLog.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/17.
//

import Foundation
import CocoaLumberjack
import RainbowSwift

enum TitledLogFlag: String {
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    case debug = "DEBUG"
    case verbose = "VERBOSE"
    case none = ""

    var name: String {
        return self.rawValue
    }

    var ddlogFlag: DDLogFlag {
        switch self {
        case .error: return .error
        case .warning: return .warning
        case .info: return .info
        case .debug: return .debug
        case .verbose: return .verbose
        case .none: return .info // default value
        }
    }

    var ddlogLevel: DDLogLevel {
        switch self {
        case .error: return .error
        case .warning: return .warning
        case .info: return .info
        case .debug: return .debug
        case .verbose: return .verbose
        case .none: return .info // default value
        }
    }

    static var allFlags: [Self] = [
        .error, .warning, .info, .debug, .verbose,
    ]
}

extension DDLogFlag {

    var title: TitledLogFlag {
        switch self {
        case .error: return .error
        case .warning: return .warning
        case .info: return .info
        case .debug: return .debug
        case .verbose: return .verbose
        default: return .none
        }
    }

    var defaultForegroundColor: Color {
        switch self {
        case .error: return .red
        case .warning: return .yellow
        case .info: return .lightWhite
        case .debug: return .green
        case .verbose: return .black
        default: return .default
        }
    }
}


extension DDLogLevel {

    var title: TitledLogFlag {
        switch self {
        case .error: return .error
        case .warning: return .warning
        case .info: return .info
        case .debug: return .debug
        case .verbose: return .verbose
        default: return .none
        }
    }
}
