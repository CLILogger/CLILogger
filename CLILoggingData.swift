//
//  CLILoggingData.swift
//  CLILogger
//
//  Created by WeiHan on 2024/8/18.
//

import Foundation
import CocoaLumberjack

@objcMembers
public class CLILoggingData: NSObject, CLILoggingProtocol {
    public private(set) var date: Date!
    public private(set) var data: Data?
    public private(set) var filename: String?
    public private(set) var fileExtension: String?

    public var identity: CLILoggingIdentity!
    public var deviceName: String!

    static var initialTag: Int {
        100
    }

    static var tagRange: Range<Int> {
        initialTag..<(Int(INT_MAX - 1))
    }
    
    var isValid: Bool {
        return Self.tagRange.contains(tag)
    }

    public private(set) var tag: Int = 0
    private static var index: Int = 0

    fileprivate override init() {
        self.date = Date()

        super.init()
    }

    public convenience init(message: String, flag: DDLogFlag = .verbose, filename: String? = nil, line: UInt? = nil, function: String? = nil) {
        self.init()
        defer {
            Self.index += 1
        }

        self.filename = filename
        self.tag = (Self.index + Self.initialTag) % Int(INT_MAX - 1)
    }

    private enum JSONKey: String {
        case date
        case filename
        case fileExtension
        case tag
        case data

        var name: String {
            get { self.rawValue }
        }
    }

    public var bufferData: Data {
        get {
            var dict: [String: Any] = [
                JSONKey.date.name: date.timeIntervalSince1970,
                JSONKey.tag.name: tag,
            ]
            
            if let filename = filename {
                dict[JSONKey.filename.name] = filename
            }
            
            if let fileExtension = fileExtension {
                dict[JSONKey.fileExtension.name] = fileExtension
            }
            
            if let data = data {
                dict[JSONKey.data.name] = data
            }

            let data = try! JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed)
            return data.base64EncodedData()
        }
    }

    public required convenience init(data: Data) {
        self.init()

        do {
            let decodedData = Data(base64Encoded: data)!
            let object = try JSONSerialization.jsonObject(with: decodedData, options: .fragmentsAllowed)
            let dict = object as! [String: Any]

            date = Date(timeIntervalSince1970: dict[JSONKey.date.name] as? TimeInterval ?? 0)
            filename = dict[JSONKey.filename.name] as? String
            fileExtension = dict[JSONKey.fileExtension.name] as? String
            self.data = dict[JSONKey.data.name] as? Data
            tag = dict[JSONKey.tag.name] as? Int ?? 0

            // print(">>> Received message [\(message ?? "")]")
        } catch {
            print("Exception: \(error)")
        }
    }
}
