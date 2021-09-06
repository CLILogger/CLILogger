//
//  CLILoggingIdentity.swift
//  CLILogger
//
//  Created by WeiHan on 2021/8/7.
//

import Foundation

#if os(macOS)
    import IOKit
#elseif os(iOS)
    import UIKit
#endif

public struct CLILoggingIdentity: CLILoggingProtocol {
    public private(set) var hostName: String
    public private(set) var deviceID: String
    public private(set) var secret: String?

    static var initialTag: Int {
        0
    }

    static var tagRange: Range<Int>{
        0..<1
    }

    public init() {
        #if os(macOS)
        hostName = Host.current().localizedName ?? "<unknown device>"
        deviceID = Self.hardwareUUID() ?? ""
        #elseif os(iOS)
        hostName = UIDevice.current.name
        deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
        #endif
    }

    public init(data: Data) {
        self.init()

        do {
            let decodedData = Data(base64Encoded: data)!
            let object = try JSONSerialization.jsonObject(with: decodedData, options: .fragmentsAllowed)
            let dict = object as! [String: Any]

            hostName = dict[JSONKey.hostName.name] as! String
            deviceID = dict[JSONKey.deviceID.name] as! String
            secret = dict[JSONKey.secret.name] as? String

            // print(">>> Received identity [\(hostName ?? "")]")
        } catch {
            print("Exception: \(error)")
        }
    }

    private enum JSONKey: String {
        case hostName
        case deviceID
        case secret

        var name: String {
            get { self.rawValue }
        }
    }

    public var bufferData: Data {
        get {
            let dict: [String: Any] = [
                JSONKey.hostName.name: hostName,
                JSONKey.deviceID.name: deviceID,
                JSONKey.secret.name: secret ?? "",
            ]

            let data = try! JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed)
            return data.base64EncodedData()
        }
    }

    #if os(macOS)
    /// https://stackoverflow.com/a/55001824/1677041
    private static func hardwareUUID() -> String?
    {
        let matchingDict = IOServiceMatching("IOPlatformExpertDevice")
        let platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDict)
        defer { IOObjectRelease(platformExpert) }

        guard platformExpert != 0 else { return nil }
        return IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0).takeRetainedValue() as? String
    }
    #endif

    public mutating func rename(to newHostName: String) {
        hostName = newHostName
    }
}

public struct CLILoggingResponse: CLILoggingProtocol {
    public var accepted: Bool?
    public var message: String?
    public static var initialTag: Int {
        1
    }
    
    static var tagRange: Range<Int> {
        1..<2
    }

    private enum JSONKey: String {
        case accepted

        var name: String {
            get { self.rawValue }
        }
    }

    public var bufferData: Data {
        get {
            let dict: [String: Any] = [
                JSONKey.accepted.name : accepted ?? false
            ]

            let data = try! JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed)
            return data.base64EncodedData()
        }
    }

    public init(_ accept: Bool, _ msg: String?) {
        accepted = accept
        message = msg
    }

    public init(data: Data) {
        do {
            let decodedData = Data(base64Encoded: data)!
            let object = try JSONSerialization.jsonObject(with: decodedData, options: .fragmentsAllowed)
            let dict = object as! [String: Any]

            accepted = dict[JSONKey.accepted.name] as? Bool
            // print(">>> Received response [\(hostName ?? "")]")
        } catch {
            print("Exception: \(error)")
        }
    }
}
