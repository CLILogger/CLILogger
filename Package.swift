// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CLILogger",
    products: [
        .library(
            name: "CLILogger",
            targets: ["CLILogger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.5"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.7.0"),
    ],
    targets: [
        .target(
            name: "CLILogger",
            dependencies: [
                "CocoaAsyncSocket",
                "CocoaLumberjack",
                "CocoaLumberjackSwift",
            ]),
    ]
)
