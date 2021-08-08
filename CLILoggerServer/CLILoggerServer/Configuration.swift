//
//  LoggingConfig.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/16.
//

import Foundation
import CocoaLumberjack
import RainbowSwift
import Yams

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

    public struct Formatter {
        public var time: String?
        public var format: String?

        enum YAMLKey: String {
            case time = "time"
            case format = "format"

            var name: String {
                return self.rawValue
            }
        }

        enum FormatKey: String, CaseIterable {
            case time = "Time"
            case flag = "Flag"
            case filename = "Filename"
            case line = "Line"
            case function = "Function"
            case message = "Message"

            var name: String {
                return self.rawValue
            }
        }

        public init(_ dict: [String: Any?]) {
            self.time = dict[YAMLKey.time.name] as? String
            self.format = dict[YAMLKey.format.name] as? String
        }

        var timeFormatter: DateFormatter? {
            if (time != nil) {
                let formatter = DateFormatter()

                formatter.dateFormat = time
                return formatter
            }

            return nil
        }
    }

    struct ColorStyle {
        var flag: DDLogFlag?
        var foregroundColor: Color?
        var backgroundColor: BackgroundColor?
        var style: Style?

        static var defaultFormatKey = "Default"

        enum YAMLKey: String {
            case foreground = "foreground"
            case background = "background"
            case style = "style"

            var name: String {
                return self.rawValue
            }
        }

        init(_ dict: [String: Any?]) {
            if let value = dict[YAMLKey.foreground.name] as? Int {
                foregroundColor = Color(rawValue: UInt8(value))
            }

            if let value = dict[YAMLKey.background.name] as? Int {
                backgroundColor = BackgroundColor(rawValue: UInt8(value))
            }

            if let value = dict[YAMLKey.style.name] as? Int {
                style = Style(rawValue: UInt8(value))
            }
        }
    }

    struct Authorization {
        var blockDevices: [String]
        var secrets: [String]

        enum YAMLKey: String {
            case blockDevices = "block-devices"
            case secrets = "secrets"

            var name: String {
                return self.rawValue
            }
        }

        init(_ dict: [String: Any?]) {
            blockDevices = dict[YAMLKey.blockDevices.name] as? [String] ?? []
            secrets = dict[YAMLKey.secrets.name] as? [String] ?? []
        }
    }

    public fileprivate(set) var projectName: String?

    public fileprivate(set) var logLevel: DDLogLevel = .verbose
    public fileprivate(set) var modules: [Module] = []

    public fileprivate(set) var serviceName: String?
    public fileprivate(set) var servicePort: UInt16?

    public fileprivate(set) var formatter: Formatter?

    fileprivate(set) var style: [String: [TitledLogFlag: ColorStyle]]?
    fileprivate(set) var authorization: Authorization?

    fileprivate var fileChangeObserver: DispatchSourceFileSystemObject?

    enum YAMLKey: String {
        case serviceName = "service-name"
        case servicePort = "service-port"
        case projectName = "project-name"
        case logLevel = "log-level"
        case formatter = "formatter"
        case style = "style"
        case whitelistModules = "whitelist-modules"
        case blocklistModules = "blocklist-modules"
        case authorization = "authorization"

        var name: String {
            self.rawValue
        }
    }
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

    public func matchModule(name: String) -> Module.Mode {
        if let _ = whitelistModules.first(where: { $0.name == name }) {
            return .whitelist
        }

        if let _ = blocklistModules.first(where: { $0.name == name }) {
            return .blocklist
        }

        return .default
    }
}

// MARK: - Default Configuration

extension Configuration {

    public static var defaultConfigFolder: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)
    }

    public static var appName: String {
        "cli-logger"
    }

    public static var defaultConfigFileExtension: String {
        "yml"
    }

    public static var defaultConfigFile: URL {
        defaultConfigFolder
            .appendingPathComponent("default", isDirectory: false)
            .appendingPathExtension(defaultConfigFileExtension)
    }

    private var defaultConfigurationContent: String {
        """
        # Configuration file for \(Self.appName) from https://github.com/CLILogger/CLILogger.

        # Public service name for client to choose, defaults to current hostname.
        \(YAMLKey.serviceName.name):

        # Defaults to 0 means assigned by system automatically.
        \(YAMLKey.servicePort.name): 0

        # Current configuration's identifier, used when launching service.
        \(YAMLKey.projectName.name): default

        # Log level from `DDLogLevel`, available options: ERROR, WARNING, INFO, DEBUG, VERBOSE, or leave it empty.
        # Note that it's case-sensitive, use the uppercase always, same with below.
        \(YAMLKey.logLevel.name): \(TitledLogFlag.verbose.name)

        # All the formatter options:
        \(YAMLKey.formatter.name):
            # The message formatter, remember to wrap the keys with `{{` and `}}` always.
            # Available formatter keys: \(Formatter.FormatKey.allCases.map({ $0.name }).reduce("", { $0 == "" ? $1 : $0 + ", " + $1 }))
            \(Formatter.YAMLKey.format.name): "{{Time}} {{Flag}} {{Filename}}:{{Line}} {{Function}}\\n{{Message}}"
            # The time formatter used for {{Time}} value.
            # References: https://nsdateformatter.com/
            \(Formatter.YAMLKey.time.name): "HH:mm:ss.SSS"

        # Style configurations.
        \(YAMLKey.style.name):
            # This default style section will be used for all the format units if no other specific section configured.
            \(ColorStyle.defaultFormatKey):
                # See the value options from https://github.com/onevcat/Rainbow/blob/master/Sources/Color.swift.
                \(ColorStyle.YAMLKey.foreground.name): \(Color.lightBlack.value)
                # See the value options from https://github.com/onevcat/Rainbow/blob/master/Sources/BackgroundColor.swift.
                \(ColorStyle.YAMLKey.background.name): \(BackgroundColor.default.value)
                # See the value options from https://github.com/onevcat/Rainbow/blob/master/Sources/Style.swift.
                \(ColorStyle.YAMLKey.style.name): \(Style.default.value)

            # Apply the classical colorful style for message by log flag:
            \(Formatter.FormatKey.message.name):
                \(TitledLogFlag.verbose.name):
                    \(ColorStyle.YAMLKey.foreground.name): \(Color.black.value)
                \(TitledLogFlag.debug.name):
                    \(ColorStyle.YAMLKey.foreground.name): \(Color.green.value)
                \(TitledLogFlag.info.name):
                    \(ColorStyle.YAMLKey.foreground.name): \(Color.lightWhite.value)
                \(TitledLogFlag.warning.name):
                    \(ColorStyle.YAMLKey.foreground.name): \(Color.yellow.value)
                \(TitledLogFlag.error.name):
                    \(ColorStyle.YAMLKey.foreground.name): \(Color.red.value)

            # One more an example:
            # \(Formatter.FormatKey.time.name):
            #    \(ColorStyle.YAMLKey.foreground.name): \(Color.default.value)
            #    \(ColorStyle.YAMLKey.style.name): \(Style.italic.value)

        # Module whitelist:
        \(YAMLKey.whitelistModules.name):
            -

        # Module blocklist:
        \(YAMLKey.blocklistModules.name):
            - \(String(describing: CLILoggingService.self))

        # Authorization settings:
        \(YAMLKey.authorization.name):
            # These devices will be blocked directly, it enables if there are any valid device identifiers.
            # Leave a single empty string here to disable the checking.
            \(Authorization.YAMLKey.blockDevices.name):
                - ""  # Block all the unknown devices
            # These secrets will be accepted directly, it enables if there are any valid secrets.
            # Leave a single empty string here to disable the checking.
            \(Authorization.YAMLKey.secrets.name):
                - ""

        # More settings are coming soon...
        """
    }
}

// MARK: - Project

extension Configuration {

    public static var allAvailableConfigurationFiles: [String] {
        let rootPath = defaultConfigFolder.path

        do {
            let filenames = try FileManager.default.contentsOfDirectory(atPath: rootPath)
            return filenames.filter { (filename) -> Bool in
                let fullpath = defaultConfigFolder.appendingPathComponent(filename).path
                var isDirectory: ObjCBool = false

                if !FileManager.default.fileExists(atPath: fullpath, isDirectory: &isDirectory) || isDirectory.boolValue {
                    return false
                }

                if filename.hasPrefix(".") {
                    return false
                }

                if !filename.hasSuffix(defaultConfigFileExtension) {
                    return false
                }

                return true
            }
        } catch {
            DDLogError("Failed to scan configuration file under directory \(rootPath)")
        }

        return []
    }

    public static var allAvailableProjects: [String] {
        var projects: [String] = []

        allAvailableConfigurationFiles.forEach { (configName) in
            let url = defaultConfigFolder.appendingPathComponent(configName)
            var config = Configuration()

            if !config.load(from: url) {
                return
            }

            guard let name = config.projectName else {
                return
            }

            projects.append(name)
        }

        return projects
    }
}

// MARK: - Color Style

extension Configuration {

    /// Apply specified style and flag for the message string.
    /// - Parameters:
    ///   - formatter: target style formatter.
    ///   - message: source message.
    ///   - flag: log flag.
    /// - Returns: formatted result message.
    func applyStyle(_ formatter: String, for message: String, with flag: DDLogFlag) -> String {
        guard let style = style else {
            return message
        }

        guard let formatStyle = (style[formatter] ?? style[ColorStyle.defaultFormatKey]) else {
            return message
        }

        guard let color = (formatStyle[flag.title] ?? formatStyle[.none]) else {
            return message
        }

        var result = message

        if let fgColor = color.foregroundColor, fgColor != .default {
            result = result.applyingColor(fgColor)
        }

        if let bgColor = color.backgroundColor, bgColor != .default {
            result = result.applyingBackgroundColor(bgColor)
        }

        if let style = color.style, style != .default {
            result = result.applyingStyle(style)
        }

        return result
    }
}

// MARK: - Load & Save

extension Configuration {

    /// Load from the specified configuration file and apply to current object.
    /// - Parameter file: specified source configuration file.
    /// - Returns: load successfully or not.
    @discardableResult
    public mutating func load(from file: URL) -> Bool {
        if !FileManager.default.fileExists(atPath: file.path) {
            return false
        }

        do {
            let data = try Data(contentsOf: file)
            let yamlSource = String(data: data, encoding: .utf8)!
            let dict = try Yams.load(yaml: yamlSource) as! [String: Any?]

            let whitelistModules: [Module] = (dict[YAMLKey.whitelistModules.name] as? [String])?.compactMap { Module(name: $0, mode: .whitelist) } ?? []
            let blocklistModules: [Module] = (dict[YAMLKey.blocklistModules.name] as? [String])?.compactMap { Module(name: $0, mode: .blocklist) } ?? []

            serviceName = dict[YAMLKey.serviceName.name] as? String
            servicePort = UInt16(dict[YAMLKey.servicePort.name] as! Int)
            projectName = dict[YAMLKey.projectName.name] as? String
            logLevel = TitledLogFlag(rawValue: dict[YAMLKey.logLevel.name] as! String)!.ddlogLevel
            modules += whitelistModules + blocklistModules

            if let formatterDict = dict[YAMLKey.formatter.name] as? [String: Any?] {
                formatter = Formatter(formatterDict)
            }

            if let styleDict = dict[YAMLKey.style.name] as? [String: Any?] {
                style = [:]

                for (format, formatValue) in styleDict {
                    guard let formatDict = formatValue as? [String : Any?] else {
                        continue
                    }

                    var styleDict: [TitledLogFlag: ColorStyle] = [:]

                    for flag in TitledLogFlag.allFlags {
                        if let colorDict = formatDict[flag.name] {
                            styleDict[flag] = ColorStyle(colorDict as! [String : Any?])
                        }
                    }

                    styleDict[.none] = ColorStyle(formatDict)
                    style![format] = styleDict
                }
            }

            if let auth = dict[YAMLKey.authorization.name] as? [String: Any?] {
                authorization = Authorization(auth)
            }
        } catch {
            DDLogError("Failed to read configuration from file \(file) with error \(error)")
            return false
        }

        return true
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
            try defaultConfigurationContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            DDLogError("Write the default configuration to \(url) failed with error \(error)")
        }

        return true
    }
}

// MARK: - Observe Changes

extension Configuration {

    /// Observe the configuration file's changes from file system.
    /// - Parameter handler: handler with new configuration object.
    public mutating func startObserve(handler: @escaping ((Configuration?) -> Void)) {
        let fileURL = Self.defaultConfigFile
        let descriptor = open(fileURL.path, O_EVTONLY)
        fileChangeObserver = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: nil)

        fileChangeObserver?.setEventHandler(handler: {
            var newConfig = Configuration()

            if newConfig.load(from: fileURL) {
                handler(newConfig)
            } else {
                handler(nil)
                DDLogError("Reloading configuration changes failed!")
            }
        })

        fileChangeObserver?.activate()
    }

    /// Stop observing the configuration file.
    public func stopObserve() {
        fileChangeObserver?.cancel()
    }

    /// Apply the properties of incoming configuration to current configuration.
    /// - Parameter config: incoming configuration.
    public mutating func applyChanges(from config: Configuration) {
        logLevel = config.logLevel
        modules = config.modules
        serviceName = config.serviceName
        servicePort = config.servicePort
        formatter = config.formatter
        style = config.style
        authorization = config.authorization
    }
}
