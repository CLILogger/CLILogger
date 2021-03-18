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

    private static var formatter: DateFormatter {
        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }

    private func prettyFormatMessage() -> String {
        var result = Self.formatter.string(from: date)
        let color = flag!.color

        result += " \(flag!.title.name.padding(toLength: 8, withPad: " ", startingAt: 0))"

        if let mod = module {
            result += " \(mod)"
        }

        result += " \(message!)"
        return result.applyingColor(color)
    }

    public func output() {
        print(prettyFormatMessage())
    }
}
