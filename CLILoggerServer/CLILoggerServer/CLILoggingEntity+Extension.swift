//
//  CLILoggingEntity+Extension.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/17.
//

import Foundation
import RainbowSwift
import CLILogger

extension CLILoggingEntity {

    private static var defaultTimeFormatter: DateFormatter {
        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }

    private func defaultFormatMessage() -> String {
        var result = Self.defaultTimeFormatter.string(from: date)
        let color = flag!.color

        result += " \(flag!.title.name.padding(toLength: 8, withPad: " ", startingAt: 0))"

        if let filename = filename {
            result += " \(filename)"
        }

        if let line = line {
            result += " \(line)"
        }

        if let function = function {
            result += " \(function)"
        }

        result += " \(message!)"
        return result.applyingColor(color)
    }

    private func customFormatMessage(_ formatter: Configuration.Formatter) -> String {
        var result = formatter.format ?? ""

        func replace(_ unit: Configuration.Formatter.ENVKey, with new: String) {
            result = result.replacingOccurrences(of: "{{\(unit.name)}}", with: new)
        }

        replace(.time, with: (formatter.timeFormatter ?? Self.defaultTimeFormatter).string(from: date))
        replace(.flag, with: flag!.title.name)
        replace(.filename, with: filename ?? "")
        replace(.line, with: (line != nil) ? "\(line!)" : "")
        replace(.function, with: function ?? "")
        replace(.message, with: message)

        return result
    }

    public func output(by formatter: Configuration.Formatter?) {
        if (formatter != nil) {

        } else {
            print(defaultFormatMessage())
        }
    }
}
