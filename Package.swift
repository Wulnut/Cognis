// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cognis",
    platforms: [
        .macOS(.v14)  // macOS 14 (Sonoma) 或更高版本
    ],
    products: [
        // CognisCore: 核心业务逻辑库
        .library(
            name: "CognisCore",
            targets: ["CognisCore"]
        ),
    ],
    dependencies: [
        // 未来依赖：
        // .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.2.0"),
        // .package(url: "https://github.com/armadsen/ORSSerialPort", from: "2.1.0"),
    ],
    targets: [
        // CognisCore 目标
        .target(
            name: "CognisCore",
            dependencies: [],
            path: "Sources/CognisCore"
        ),
        // 测试目标
        .testTarget(
            name: "CognisCoreTests",
            dependencies: ["CognisCore"],
            path: "Tests/CognisCoreTests"
        ),
    ]
)
