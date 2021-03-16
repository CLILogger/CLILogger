//
//  LoggingConfig.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/16.
//

import Foundation
import CocoaLumberjack

// MARK: - Main Structure

public struct Configuration {

    public struct Module {
        public enum Mode: Int {
            case whitelist = 1
            case `default` = 0
            case blocklist = -1
        }

        public var mode: Mode = .default
        public var name: String?

        public var isValid: Bool {
            return !(name?.isEmpty ?? true)
        }

        public init(name: String?, mode: Mode = .default) {
            self.name = name
            self.mode = mode
        }
    }

    public fileprivate(set) var logLevel: DDLogLevel = .info
    public fileprivate(set) var modules: [Module] = []

    public fileprivate(set) var serviceName: String?
    public fileprivate(set) var servicePort: UInt16?
}

// MARK: - Modules

extension Configuration {

    public var whitelistModules: [Module] {
        get { return modules.filter { $0.isValid && $0.mode == .whitelist } }
    }
    public var blocklistModules: [Module] {
        get { return modules.filter { $0.isValid && $0.mode == .blocklist } }
    }

    public mutating func addModule(name: String, mode: Module.Mode = .default) {
        modules.append(Module(name: name, mode: mode))
    }

    public mutating func addModule(klass: AnyClass, mode: Module.Mode = .default) {
        addModule(name: String(describing: klass), mode: mode)
    }
}

// MARK: - Default Configuration

extension Configuration {

    public static var defaultConfigFile: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("clilogger", isDirectory: true)
            .appendingPathComponent("config.plist", isDirectory: false)
    }

    @discardableResult
    public func saveToDefaultFileIfNecessary() -> Bool {
        let url = Self.defaultConfigFile
        let path = url.path

        if FileManager.default.fileExists(atPath: path) {
            return false
        }

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            save(to: url)
        } catch {
            print("Create intermediate directory for \(url) failed with error \(error)")
        }

        return true
    }
}

// MARK: - Load & Save

extension Configuration {

    enum JSONKey: String {
        case logLevel = "LogLevel"
        case whitelistModules = "WhitelistModules"
        case blocklistModules = "BlocklistModules"
        case serviceName = "ServiceName"
        case servicePort = "ServicePort"

        var name: String {
            return self.rawValue
        }
    }

    @discardableResult
    public mutating func load(from file: URL) -> Bool {
        if !FileManager.default.fileExists(atPath: file.path) {
            return false
        }

        do {
            let data = try Data(contentsOf: file)
            let dict = try PropertyListSerialization.propertyList(from: data, options: .init(rawValue: 0), format: nil) as! [String: Any]
            let whitelistModules: [Module] = (dict[JSONKey.whitelistModules.name] as! [String?]).map { Module(name: $0, mode: .whitelist) }
            let blocklistModules: [Module] = (dict[JSONKey.blocklistModules.name] as! [String?]).map { Module(name: $0, mode: .blocklist) }

            self.logLevel = DDLogLevel(rawValue: dict[JSONKey.logLevel.name] as! UInt) ?? .info
            self.modules += whitelistModules + blocklistModules
            self.serviceName = dict[JSONKey.serviceName.name] as? String
            self.servicePort = dict[JSONKey.servicePort.name] as? UInt16
        } catch {
            print("Failed to read configuration from file \(file) with error \(error)")
            return false
        }

        return true
    }

    @discardableResult
    private func save(to file: URL) -> Bool {
        let dict: [String: Any] = [
            JSONKey.logLevel.name: logLevel.rawValue,
            JSONKey.whitelistModules.name: whitelistModules.map { $0.name },
            JSONKey.blocklistModules.name: blocklistModules.map { $0.name },
            JSONKey.serviceName.name: serviceName ?? "",
            JSONKey.servicePort.name: servicePort ?? 0,
        ]

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: .max)
            try data.write(to: file)
        } catch {
            print("Failed to save configuration with error \(error)")
            return false
        }

        return true
    }
}
