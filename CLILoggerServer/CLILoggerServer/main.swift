//
//  main.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/6.
//

import Foundation
import ArgumentParser
import CocoaLumberjack
import CLILogger

var config: Configuration!
var service: CLILoggingService!

let allConfigFiles = Configuration.allAvailableConfigurationFiles
let allProjects = Configuration.allAvailableProjects

struct App: ParsableCommand {

    @Argument(help: "Project names.", completion: .list(allProjects), transform: {_ in allProjects})
    var projectNames: [String]?

    @Flag(help: "Show verbose logging of internal service or not.")
    var verbose = false

    @Option(name: .shortAndLong, help: "The service name, defaults to current device host name.")
    var serviceName: String?

    @Option(name: .shortAndLong, help: "The service port number, defaults to automatic.")
    var port: UInt16?

    @Option(name: .shortAndLong, help: "Configuration file path, defaults to \(Configuration.defaultConfigFile.path)", completion: .file(extensions: [Configuration.defaultConfigFileExtension]))
    var file: String?
    
    static var _commandName: String {
        Configuration.appName
    }

    mutating func run() throws {
        setupInternalLogger(level: verbose ? .verbose : .info)
        setupConfiguration()

        setupService()
        service.publish()
    }

    // MARK: - Private

    func setupInternalLogger(level: DDLogLevel) {
        if (ProcessInfo().environment["TERM"] != nil) {
            // Terminal
            DDLog.add(DDTTYLogger.sharedInstance!, with: level)
        } else {
            // Xcode Console
            DDLog.add(DDOSLogger.sharedInstance, with: level)
        }

        // Disable the line buffer of print.
        setbuf(__stdoutp, nil)
    }

    func setupConfiguration() {
        config = Configuration()

        if let path = file {
            config.load(from: URL(fileURLWithPath: path))
        } else {
            if !config.load(from: Configuration.defaultConfigFile) {
                config.addModule(klass: CLILoggingService.self, mode: .blocklist)
                config.saveToDefaultFileIfNecessary()
            }
        }

        config.startObserve { newConfiguration in
            guard let newConfig = newConfiguration else {
                return
            }

            config.applyChanges(from: newConfig)
            DDLogInfo("Reloaded latest configuration changes!")
            DDLogVerbose("Note that new changes only affect the log level and module settings")
        }
    }

    func setupService() {
        service = CLILoggingService()

        service.serviceName = serviceName ?? config.serviceName ?? ""
        service.port = port ?? config.servicePort ?? 0

        service.foundIncomingIdentity = { identity in
            DDLogVerbose("Found new client identity: \(identity.hostName), \(identity.deviceID)")

            if let deviceIDs = config.authorization?.blockDevices,
               !deviceIDs.isEmpty, deviceIDs.contains(identity.deviceID) {
                DDLogVerbose("Blocke client [\(identity.hostName)] due to blocked device identifier!")
                return false
            }

            if let secrets = config.authorization?.secrets.filter({ $0.count > 0 }),
                let secret = identity.secret, !secrets.isEmpty, !secrets.contains(secret) {
                DDLogVerbose("Blocke client [\(identity.hostName)] due to missing valid secret!")
                return false
            }

            DDLogInfo("Welcome \(identity.hostName)!")
            return true
        }

        service.foundIncomingMessage = { entity in
            guard (entity.flag.rawValue & config.logLevel.rawValue) != 0 else {
                return
            }

            guard let filename = entity.filename else {
                // Output log entity if filename is nil.
                entity.output(by: config)
                return
            }

            let mode = config.matchModule(name: filename)

            if mode == .whitelist || mode == .default {
                entity.output(by: config)
            } else {
                // Nothing happens if it's in block list.
            }
        }
    }
}

App.main()

RunLoop.current.run()
