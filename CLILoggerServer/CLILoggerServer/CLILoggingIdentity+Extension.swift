//
//  CLILoggingIdentity+Extension.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/8/14.
//

import Foundation
import CLILogger

extension CLILoggingIdentity {

    private var rawMessage: String {
        var result = """
        ================================================================================
        > An identity from [\(hostName)] has been approved!
        > Device ID: \(deviceID)
        > Secret: \(secret ?? "")
        > Date: \(Date().description(with: .current))
        ================================================================================
        """

        if let secret = secret {
            result = result + " " + secret
        }

        return result
    }

    public func getLogFile(by config: Configuration, err: inout Error?) -> URL? {
        guard let fileConfig = config.loggingFile, fileConfig.enabled, var dir = fileConfig.directory else {
            return nil
        }

        var dirURL = URL(fileURLWithPath: NSString(string: dir).expandingTildeInPath)
        let formatter = DateFormatter()

        formatter.dateFormat = "yyyy-MM-dd"
        dirURL = dirURL.appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        dir = dirURL.path

        var isDir: ObjCBool = false

        if !FileManager.default.fileExists(atPath: dir, isDirectory: &isDir) || !isDir.boolValue {
            do {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                err = error
            }
        }

        var filename = "\(hostName).log"

        filename = filename.replacingOccurrences(of: "\r", with: "")
        filename = filename.replacingOccurrences(of: "\n", with: "")
        filename = filename.replacingOccurrences(of: "/", with: "")

        return URL(fileURLWithPath: dir).appendingPathComponent(filename)
    }

    public func save(by config: Configuration) -> Error? {
        guard var data = rawMessage.data(using: .utf8) else {
            return nil
        }

        var error: Error? = nil
        guard let fileURL = getLogFile(by: config, err: &error) else {
            return error
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            var newData = "\n\n".data(using: .utf8)!

            newData.append(data)
            data = newData
        }

        data.append("\n".data(using: .utf8)!)

        return data.append(to: fileURL)
    }
}

extension Data {

    /// Append the current data to specified file.
    /// - Parameter file: target file URL.
    /// - Returns: Write file error throw if encountered.
    func append(to file: URL) -> Error? {
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let fileHandler = try FileHandle(forWritingTo: file)

                fileHandler.seekToEndOfFile()
                fileHandler.write(self)
                fileHandler.closeFile()
            } else {
                try self.write(to: file, options: .atomic)
            }
        } catch {
            return error
        }

        return nil
    }
}
