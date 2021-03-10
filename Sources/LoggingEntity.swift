//
//  LoggingEntity.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaLumberjack

public struct LoggingEntity {
    private var date: Date
    private var level: DDLogLevel
    private var module: String?
    private var message: String

    public private(set) var tag: Int = 0
    private static var index: Int = 0

    init(message: String, level: DDLogLevel = .debug) {
        defer {
            Self.index += 1
        }

        self.message = message
        self.level = level
        self.date = Date()
        self.tag = Self.index
    }
}

extension LoggingEntity {

    enum JSONKey: String {
        case date
        case level
        case module
        case message

        var name: String {
            get { self.rawValue }
        }
    }

    public var bufferData: Data {
        get {
            var dict: [String: Any] = [
                JSONKey.date.name: date,
                JSONKey.level.name: level,
                JSONKey.message.name: message,
            ]

            if let mod = module {
                dict[JSONKey.module.name] = mod
            }

            var data = try! JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed)
            data.append(Data.terminator)

            return data
        }
    }

    public init(data: Data) {
        let object = try! JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        let dict = object as! [String: Any]

        self.date = dict[JSONKey.date.name] as! Date
        self.level = dict[JSONKey.level.name] as! DDLogLevel
        self.module = dict[JSONKey.module.name] as! String?
        self.message = dict[JSONKey.message.name] as! String
    }
}

extension Data {
    public static var terminator: Data {
        get {
            return Data()
        }
    }
}
