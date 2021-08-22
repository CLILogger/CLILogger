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

            if let error = identity.save(by: config) {
                DDLogError("\(error)")
            }

            return true
        }

        service.foundIncomingMessage = { entity in
            if let error = entity.save(by: config) {
                DDLogError("\(error)")
            }

            guard (entity.flag.rawValue & config.logLevel.rawValue) != 0 else {
                return
            }

            if let filename = entity.filename, config.matchModule(name: filename) == .blocklist {
                return
            }

            entity.output(by: config)
        }

        service.resolveDeviceName = {[weak service] entity in
            guard let identity = entity.identity else {
                return ""
            }

            var name = identity.hostName

            switch config.deviceShowOption {
            case .never:
                name = ""
                break
            case .automatic:
                name = service!.connectedSocketCount <= 1 ? "" : name
                break
            case .always:
                break
            }

            return name
        }
    }
}

App.main()

RunLoop.current.run()




//let sourceRange: Range<Int> = 0..<100
//let subRanges: [Range<Int>] = [
//    1..<5,
//    8..<20,
//    10..<30,
//]
//
//print(reverse_range(sourceRange, subranges: subRanges))



import RainbowSwift

let entry = Rainbow.Entry(
    segments: [
        .init(text: "Hello ", color: .named(.magenta)),
        .init(text: "Rainbow ", color: .bit8(214), backgroundColor: .named(.black), styles: [.underline]),
        .init(text: "Hello ", color: .named(.magenta)/*, backgroundColor: .named(.default)*/),  // Comment 1
        .init(text: "again", color: .named(.magenta), backgroundColor: .named(.red), styles: [.default]),  // Comment 2
    ]
)
print("")
print(Rainbow.generateString(for: entry))
print("")




//
//func rearrange_ranges(_ subranges: [Range<Int>: Any]) -> [Range<Int>: Any] {
//    var result_ranges: [Range<Int>: Any] = [:]
//    var separator_indexes: Set<Int> = .init()
//
//    for subrange in subranges.keys {
//        separator_indexes.update(with: subrange.lowerBound)
//        separator_indexes.update(with: subrange.upperBound)
//    }
//
//    var last_index: Int = 0
//
//    for idx in separator_indexes.sorted() {
//        print("\(idx)")
//
//        if last_index != idx {
//            result_ranges[last_index..<idx] = ""
//            last_index = idx
//        }
//    }
//
//    return result_ranges
//}

// 0  1    5    7    8    10    15     20    30       100
// <                                              >
//    <    >
//                   <                  >
//                        <      >
//                        <                   >
//              <         >

//let sourceRanges: [Range<Int>: String] = [
//    0..<100 : "[0-100]",
//    1..<5 : "[1-5]",
//    8..<20 : "[8-20]",
//    10..<30 : "[10-30]",
//    10..<15 : "[10-15]",
//    7..<10 : "[7-10]",
//]
//
//print(sourceRanges)
//print(rearrange_ranges(sourceRanges))



