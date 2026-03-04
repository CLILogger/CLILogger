// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "CLILogger",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15)
    ],
    products: [
        .library(name: "CLILogger", targets: ["CLILogger"])
    ],
    dependencies: [
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket", from: "7.6.4"),
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack", from: "3.9.0"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "4.0.0")
    ],
    targets: [
        .target(name: "CLILogger", dependencies: [
            .product(name: "CocoaAsyncSocket", package: "CocoaAsyncSocket"),
            .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            .product(name: "CocoaLumberjackSwift", package: "CocoaLumberjack"),
            .product(name: "Rainbow", package: "Rainbow")
        ], path: "Sources")
    ]
)
