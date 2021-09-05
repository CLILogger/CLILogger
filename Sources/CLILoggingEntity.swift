//
//  CLILoggingEntity.swift
//  CLILogger
//
//  Created by WeiHan on 2021/3/7.
//

import Foundation
import CocoaLumberjack

@objcMembers
public class CLILoggingEntity: NSObject {
    public private(set) var date: Date!
    public private(set) var flag: DDLogFlag!
    public private(set) var filename: String?
    public private(set) var line: UInt?
    public private(set) var function: String?
    public private(set) var message: String!

    public var identity: CLILoggingIdentity!
    public var deviceName: String!

    static var initialTag: Int {
        100
    }

    static var tagRange: Range<Int> {
        initialTag..<(Int(INT_MAX - 1))
    }

    public internal(set) var tag: Int? = 0
    private static var index: Int = 0

    fileprivate override init() {
        self.date = Date()
        self.flag = .verbose

        super.init()
    }

    public convenience init(message: String, flag: DDLogFlag = .verbose, filename: String? = nil, line: UInt? = nil, function: String? = nil) {
        self.init()
        defer {
            Self.index += 1
        }

        self.message = message
        self.flag = flag
        self.filename = filename
        self.line = line
        self.function = function
        self.tag = (Self.index + Self.initialTag) % Int(INT_MAX - 1)
    }
}

extension CLILoggingEntity {

    private enum JSONKey: String {
        case date
        case flag
        case filename
        case line
        case function
        case message

        var name: String {
            get { self.rawValue }
        }
    }

    public var bufferData: Data {
        get {
            var dict: [String: Any] = [
                JSONKey.date.name: date.timeIntervalSince1970,
                JSONKey.flag.name: flag.rawValue,
                JSONKey.message.name: message!,
            ]

            if let filename = filename {
                dict[JSONKey.filename.name] = filename
            }

            if let line = line {
                dict[JSONKey.line.name] = line
            }

            if let function = function {
                dict[JSONKey.function.name] = function
            }

            let data = try! JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed)
            return data.base64EncodedData()
        }
    }

    public convenience init(data: Data) {
        self.init()

        do {
            let decodedData = Data(base64Encoded: data)!
            let object = try JSONSerialization.jsonObject(with: decodedData, options: .fragmentsAllowed)
            let dict = object as! [String: Any]

            date = Date(timeIntervalSince1970: dict[JSONKey.date.name] as! TimeInterval)
            flag = DDLogFlag(rawValue: dict[JSONKey.flag.name] as! UInt)
            filename = dict[JSONKey.filename.name] as! String?
            line = dict[JSONKey.line.name] as! UInt?
            function = dict[JSONKey.function.name] as! String?
            message = dict[JSONKey.message.name] as? String

            // print(">>> Received message [\(message ?? "")]")
        } catch {
            print("Exception: \(error)")
        }
    }
}
