//
//  CLILoggingEntity+Extension.swift
//  CLILoggerServer
//
//  Created by WeiHan on 2021/3/17.
//

import Foundation
import RainbowSwift
import CLILogger

/// Reverse the subranges in source range.
private func reverse_range(_ range: Range<Int>, subranges: [Range<Int>]) -> [Range<Int>] {
    var result_ranges: [Range<Int>] = []
    var last_reverse_index: Int?

    for idx in range {
        var found = false

        for subrange in subranges {
            if subrange.contains(idx) {
                found = true
                break
            }
        }

        if !found {
            if last_reverse_index == nil {
                last_reverse_index = idx
            }

            if idx == range.upperBound - 1 {
                result_ranges.append(Range(last_reverse_index!...idx))
            }
        } else if last_reverse_index != nil {
            result_ranges.append(Range(last_reverse_index!...idx - 1))
            last_reverse_index = nil
        }
    }

    return result_ranges
}

/// Sort the ranges by its lower bound. (Bubble sort)
private func sort_range(_ ranges: [Range<Int>]) -> [Range<Int>] {
    var array = ranges

    for _ in 0..<array.count {
      for j in 1..<array.count {
        if array[j].lowerBound < array[j-1].lowerBound {
          let tmp = array[j-1]
          array[j-1] = array[j]
          array[j] = tmp
        }
      }
    }

    return array
}

extension CLILoggingEntity {

    private static var defaultTimeFormatter: DateFormatter {
        let formatter = DateFormatter()

        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }

    private var rawMessage: String {
        var result = ""

        if let date = date {
            result = result + Self.defaultTimeFormatter.string(from: date)
        }

        if let flag = flag {
            result = result + " " + flag.title.name.padding(toLength: 7, withPad: " ", startingAt: 0)
        }

        if let filename = filename {
            result = result + " " + filename

            if let line = line {
                result = result + ":" + "\(line)"
            }
        }

        if let function = function {
            result = result + " " + function
        }

        if let message = message {
            result = result + " " + message
        }

        return result
    }

    private func replaceValue(_ value: String, with config: Configuration) -> String {
        let formatterKey = Configuration.Formatter.FormatKey.allCases.first { "{{\($0.name)}}" == value}
        var replacedValue = value

        for key in Configuration.Formatter.FormatKey.allCases {
            if formatterKey != key {
                continue
            }

            switch key {
            case .time:
                replacedValue = (config.formatter!.timeFormatter ?? Self.defaultTimeFormatter).string(from: date)
                break

            case .flag:
                replacedValue = flag!.title.name.padding(toLength: 7, withPad: " ", startingAt: 0)
                break

            case .filename:
                replacedValue = filename ?? ""
                break

            case .line:
                replacedValue = (line != nil) ? "\(line!)" : ""
                break

            case .function:
                replacedValue = function ?? ""
                break

            case .message:
                replacedValue = message
                break
            }
        }

        return config.applyStyle(formatterKey?.name ?? "", for: replacedValue, with: flag)
    }

    private func customFormatMessage(_ config: Configuration) -> String {
        guard let formatter = config.formatter else {
            return rawMessage
        }

        let source = formatter.format ?? ""

        let regex = try! NSRegularExpression(pattern: "\\{\\{\\w+\\}\\}")
        let results = regex.matches(in: source, options: [.reportCompletion, .withTransparentBounds], range: NSRange(location: 0, length: source.count))

        let matchedRanges = results.map { Range(uncheckedBounds: ($0.range.location, $0.range.location + $0.range.length)) }
        let reversedRanges = reverse_range(0..<source.count, subranges: matchedRanges)
        let allRanges = sort_range(matchedRanges + reversedRanges)
        var result = ""

        for r in allRanges {
            let start = source.index(source.startIndex, offsetBy: r.lowerBound)
            let end = source.index(source.startIndex, offsetBy: r.upperBound)
            let unit = String(source[start..<end])

            result += replaceValue(unit, with: config)
        }

        return result
    }

    public func output(by config: Configuration) {
        print(customFormatMessage(config))
    }
}
