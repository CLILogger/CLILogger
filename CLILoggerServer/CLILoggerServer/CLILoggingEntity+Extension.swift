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
///
/// For example:
///     source range:   0   2   5   7   8   9
///     sub-range1:         [...]
///     sub-range2:                 [...]
///     result ranges:  [...]   [...]   [...]
///
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

/// Bubble sort on range.
private func sort_range<INDEX>(_ ranges: [Range<INDEX>], by: (Range<INDEX>, Range<INDEX>) -> Bool) -> [Range<INDEX>] {
    var array = ranges

    for _ in 0..<array.count {
        for j in 1..<array.count {
            let cur = array[j], pre = array[j - 1]

            if !by(pre, cur) {
                let tmp = pre
                array[j - 1] = cur
                array[j] = tmp
            }
        }
    }

    return array
}

/// Sort the ranges by its lower bound with ascending order.
private func sort_range<INDEX>(_ ranges: [Range<INDEX>]) -> [Range<INDEX>] {
    sort_range(ranges) { r1, r2 in
        r1.lowerBound < r2.lowerBound
    }
}

func rearrange_ranges<INDEX>(_ subranges: [Range<INDEX>: Any]) -> [Range<INDEX>: Any] {
    var result_ranges: [Range<INDEX>: Any] = [:]
    var separator_indexes: Set<INDEX> = .init()

    for subrange in subranges.keys {
        separator_indexes.update(with: subrange.lowerBound)
        separator_indexes.update(with: subrange.upperBound)
    }

    func value_for(index: INDEX) -> Any {
        var matches: [Range<INDEX>] = []

        let sorted = sort_range(Array(subranges.keys)) { r1, r2 in
            r1.lowerBound < r2.lowerBound || (r1.lowerBound == r2.lowerBound && r1.upperBound > r2.upperBound)
        }
        // print("sorted: \(sorted)")

        for range in sorted {
            if range.lowerBound <= index && range.upperBound > index {
                matches.append(range)
                // print("     matches: \(range)")
            }
        }

        if let topRange = matches.last {
            return subranges[topRange]!
        }

        assert(false, "Fatal wrong routes!")
        return ""
    }

    var last_index: INDEX?

    for idx in separator_indexes.sorted() {
        // print("\ntarget: \(idx)")

        if last_index == nil {
            last_index = idx
        } else if last_index != idx {
            let value = value_for(index: last_index!)
            result_ranges[last_index!..<idx] = value
            // print("new range: \(last_index!..<idx) = \(value)")
            last_index = idx
        }
    }

    return result_ranges
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
        let formatterKey = Configuration.Formatter.FormatKey.allCases.first(where: { "{{\($0.name)}}" == value })
        var replacedValue = value

        switch formatterKey {
        case .time:
            replacedValue = (config.formatter!.timeFormatter ?? Self.defaultTimeFormatter).string(from: date)
        case .flag:
            replacedValue = flag!.title.name.padding(toLength: 7, withPad: " ", startingAt: 0)
        case .filename:
            replacedValue = filename ?? ""
        case .line:
            replacedValue = (line != nil) ? "\(line!)" : ""
        case .function:
            replacedValue = function ?? ""
        case .message:
            replacedValue = message
        case .device:
            // Append a empty space to the ending of device name to separate it from other format units.
            replacedValue = "\(deviceName!) "
        case .none:
            replacedValue = value
        }

        let colorStyle = config.colorStyleFor(formatterKey?.name, with: flag)
        return applyStyle(colorStyle, for: replacedValue)
    }

    private func applyStyle(_ style: Configuration.ColorStyle?, for message: String) -> String {
        var colorRanges: [Range<String.Index>: Configuration.ColorStyle] = [:]
        var result: String = ""

        if let style = style {
            colorRanges[message.startIndex..<message.endIndex] = style
        }

        let debugMessage: String? = nil

        let highlightCS = config.highlightColorStyleFor(message: message)
        colorRanges.merge(highlightCS) { cs1, cs2 in cs2 }
        colorRanges = rearrange_ranges(colorRanges) as! [Range<String.Index>: Configuration.ColorStyle]

        if message == debugMessage {
            print("Source: [\(message)]")
        }

        for range in colorRanges.keys.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let colorStyle = colorRanges[range] {
                result += colorStyle.apply(to: String(message[range]))

                if message == debugMessage {
                    print("     Match: [\(String(message[range]))], colorful: [\(colorStyle.apply(to: String(message[range])))], range: \(range.lowerBound.utf16Offset(in: message)):\(range.upperBound.utf16Offset(in: message))")
                }
            }
        }

        if message == debugMessage {
            print("Result: [\(result)]")
        }
        return result
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

    public func save(by config: Configuration) -> Error? {
        guard var data = rawMessage.data(using: .utf8) else {
            return nil
        }

        data.append("\n".data(using: .utf8)!)

        var error: Error? = nil
        guard let fileURL = identity.getLogFile(by: config, err: &error) else {
            return error
        }

        return data.append(to: fileURL)
    }
}
