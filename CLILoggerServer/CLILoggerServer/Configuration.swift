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
            case device = "Device"

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

        func apply(to text: String) -> String {
            var result = text

            if let fgColor = foregroundColor, fgColor != .default {
                result = result.applyingColor(fgColor)
            }

            if let bgColor = backgroundColor, bgColor != .default {
                result = result.applyingBackgroundColor(bgColor)
            }

            if let style = style, style != .default {
                result = result.applyingStyle(style)
            }

            return result
        }

        func apply(to text: String) -> Rainbow.Segment {
            var result = Rainbow.Segment(text: text)

            result.color = ColorType.named(foregroundColor ?? .default)
            result.backgroundColor = BackgroundColorType.named(backgroundColor ?? .default)
            result.styles = [style ?? .default]

            return result
        }
    }

    struct Highlight {
        var style: ColorStyle?
        var texts: [String]?
        var regexes: [String]?

        enum YAMLKey: String {
            case text, regex

            var name: String {
                return self.rawValue
            }
        }

        init(_ dict: [String: Any?]) {
            if let value = dict[YAMLKey.text.name] as? [String] {
                texts = value
            }

            if let value = dict[YAMLKey.regex.name] as? [String] {
                regexes = value
            }

            style = ColorStyle(dict)
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

    struct DeviceAlias {
        var identifier: String?
        var alias: String?

        enum YAMLKey: String {
            case identifier, alias

            var name: String {
                return self.rawValue
            }
        }

        init(_ dict: [String?: String?]) {
            identifier = dict[YAMLKey.identifier.name] as? String
            alias = dict[YAMLKey.alias.name] as? String
        }
    }

    enum DeviceShowOption: String, CaseIterable {
        case never
        case automatic
        case always

        var name: String {
            self.rawValue
        }
    }

    struct LoggingFile {
        var enabled: Bool
        var directory: String?

        enum YAMLKey: String {
            case enabled, directory

            var name: String {
                return self.rawValue
            }
        }

        init(_ dict: [String?: Any?]) {
            enabled = dict[YAMLKey.enabled.name] as? Bool ?? false
            directory = dict[YAMLKey.directory.name] as? String
        }
    }

    public fileprivate(set) var projectName: String?

    public fileprivate(set) var logLevel: DDLogLevel = .verbose
    public fileprivate(set) var modules: [Module] = []

    public fileprivate(set) var serviceName: String?
    public fileprivate(set) var servicePort: UInt16?

    public fileprivate(set) var formatter: Formatter?

    fileprivate(set) var style: [String: [TitledLogFlag: ColorStyle]]?
    fileprivate(set) var highlights: [Highlight]?
    fileprivate(set) var authorization: Authorization?
    fileprivate(set) var deviceAliases: [DeviceAlias]?
    fileprivate(set) var deviceShowOption: DeviceShowOption = .automatic
    fileprivate(set) var loggingFile: LoggingFile?

    fileprivate var fileChangeObserver: DispatchSourceFileSystemObject?

    enum YAMLKey: String {
        case serviceName = "service-name"
        case servicePort = "service-port"
        case projectName = "project-name"
        case logLevel = "log-level"
        case formatter = "formatter"
        case style = "style"
        case highlights = "highlights"
        case whitelistModules = "whitelist-modules"
        case blocklistModules = "blocklist-modules"
        case authorization = "authorization"
        case deviceAliases = "device-aliases"
        case showDevice = "show-device"
        case loggingFile = "logging-file"

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
        # Restarting the logging service is required if updates.
        \(YAMLKey.serviceName.name):

        # Defaults to 0 means assigned by system automatically.
        # Restarting the logging service is required if updates.
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
            \(Formatter.YAMLKey.format.name): "{{Time}} {{Device}}{{Flag}} {{Filename}}:{{Line}} {{Function}}\\n{{Message}}"
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
            # Set separated font style for the time unit.
            # \(Formatter.FormatKey.time.name):
            #    \(ColorStyle.YAMLKey.foreground.name): \(Color.default.value)
            #    \(ColorStyle.YAMLKey.style.name): \(Style.italic.value)

        # Highlight these texts and regex express by prefer styles.
        # Note that texts will be matched first one by one, regex follows the same.
        # If there are some intersection units when matching, the latter one will overwrite the former ones.
        \(YAMLKey.highlights.name):
            - \(ColorStyle.YAMLKey.foreground.name): \(Color.yellow.value)
              \(ColorStyle.YAMLKey.background.name): \(BackgroundColor.black.value)
              \(ColorStyle.YAMLKey.style.name): \(Style.blink.value)
              \(Highlight.YAMLKey.text.name):
                -
              \(Highlight.YAMLKey.regex.name):
                -

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

        # Device aliases:
        \(YAMLKey.deviceAliases.name):
            - \(DeviceAlias.YAMLKey.identifier.name):
              \(DeviceAlias.YAMLKey.alias.name):

        # Show device name in logging message or not, defaults to \(DeviceShowOption.automatic.name).
        # Notes: to separate device name from other format units, it will always append a empty space to the ending of real device name.
        # Available options:
        #   \(DeviceShowOption.never.name): show never, even {{\(Formatter.FormatKey.device.name)}} configured.
        #   \(DeviceShowOption.automatic.name): show when there are two at least connected devices.
        #   \(DeviceShowOption.always.name): show always.
        \(YAMLKey.showDevice.name): \(DeviceShowOption.automatic.name)

        # Redirect all the logging messages to file under the following specified directory.
        \(YAMLKey.loggingFile.name):
            \(LoggingFile.YAMLKey.enabled.name): false
            \(LoggingFile.YAMLKey.directory.name): \(NSHomeDirectory())/Library/Logs/\(Self.appName)/

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

    /// Get color style for specified style and flag.
    /// - Parameters:
    ///   - formatter: target style formatter.
    ///   - flag: log flag.
    /// - Returns: target color style.
    func colorStyleFor(_ formatter: String?, with flag: DDLogFlag) -> ColorStyle? {
        guard let style = style else {
            return nil
        }

        guard let fmt = formatter, let formatStyle = style[fmt] else {
            let formatStyle = style[ColorStyle.defaultFormatKey]
            return formatStyle?[flag.title] ?? formatStyle?[.none]
        }

        return formatStyle[flag.title] ?? formatStyle[.none]
    }

    func highlightColorStyleFor(message: String) -> [Range<String.Index>: ColorStyle] {
        var results: [Range<String.Index>: ColorStyle] = [:]

        for highlight in highlights ?? [] {
            guard let style = highlight.style else {
                continue
            }

            for text in highlight.texts ?? [] {
                if let range = message.range(of: text) {
                    results[range] = style
                }
            }

            for regex in highlight.regexes ?? [] {
                let regex = try! NSRegularExpression(pattern: regex)
                let matches = regex.matches(in: message, options: [.reportCompletion, .withTransparentBounds], range: NSRange(location: 0, length: message.count))

                for match in matches {
                    let start = message.index(message.startIndex, offsetBy: match.range.location)
                    let end = message.index(message.startIndex, offsetBy: NSMaxRange(match.range))
                    let range = start..<end

                    results[range] = style
                }
            }
        }

        return results
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

            if let highlightDict = dict[YAMLKey.highlights.name] as? [[String: Any?]] {
                highlights = highlightDict.map { Highlight($0) }
            }

            if let auth = dict[YAMLKey.authorization.name] as? [String: Any?] {
                authorization = Authorization(auth)
            }

            if let aliases = dict[YAMLKey.deviceAliases.name] as? [[String?: String?]] {
                deviceAliases = aliases.map({ DeviceAlias($0) }).filter({ $0.identifier?.count ?? 0 > 0 && $0.alias?.count ?? 0 > 0 })
            }

            if let value = dict[YAMLKey.showDevice.name] as? String, let option = DeviceShowOption(rawValue: value) {
                deviceShowOption = option
            }

            if let fileConfig = dict[YAMLKey.loggingFile.name] as? [String?: Any?] {
                loggingFile = LoggingFile(fileConfig)
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
        highlights = config.highlights
        authorization = config.authorization
        deviceAliases = config.deviceAliases
        deviceShowOption = config.deviceShowOption
        loggingFile = config.loggingFile
    }
}
