//
//  LoggingEntity.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaLumberjack

@objcMembers
public class LoggingEntity: NSObject {
    public private(set) var date: Date!
    public private(set) var level: DDLogLevel!
    public private(set) var module: String?
    public private(set) var message: String!

    public private(set) var tag: Int = 0
    private static var index: Int = 0

    fileprivate override init() {
        self.date = Date()
        self.level = .debug

        super.init()
    }

    public convenience init(message: String, level: DDLogLevel = .debug, module: String? = nil) {
        self.init()
        defer {
            Self.index += 1
        }

        self.message = message
        self.level = level
        self.module = module
        self.tag = Self.index
    }
}

extension LoggingEntity {

    private enum JSONKey: String {
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
                JSONKey.date.name: date.timeIntervalSince1970,
                JSONKey.level.name: level.rawValue,
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

    public convenience init(data: Data) {
        let object = try! JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        let dict = object as! [String: Any]

        self.init()

        self.date = Date(timeIntervalSince1970: dict[JSONKey.date.name] as! TimeInterval)
        self.level = DDLogLevel(rawValue: dict[JSONKey.level.name] as! UInt) ?? .off
        self.module = dict[JSONKey.module.name] as! String?
        self.message = dict[JSONKey.message.name] as! String
    }
}

extension Data {
    public static var terminator: Data {
        get {
            // https://stackoverflow.com/a/24850996/1677041
            let bytes = [0x0D, 0x0A, 0x0B, 0x0A]
            return Data(bytes: bytes, count: bytes.count)
        }
    }
}
