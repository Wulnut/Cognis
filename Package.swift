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
        // CognisApp: macOS 可执行应用
        .executable(
            name: "CognisApp",
            targets: ["CognisApp"]
        ),
    ],
    dependencies: [
        // 终端仿真渲染
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0"),
        // .package(url: "https://github.com/armadsen/ORSSerialPort", from: "2.1.0"),
    ],
    targets: [
        // CognisCore 目标
        .target(
            name: "CognisCore",
            dependencies: [],
            path: "Sources/CognisCore"
        ),
        // CognisApp 应用目标
        .executableTarget(
            name: "CognisApp",
            dependencies: [
                "CognisCore",
                .product(name: "SwiftTerm", package: "SwiftTerm")
            ],
            path: "Sources/CognisApp"
        ),
        // 测试目标
        .testTarget(
            name: "CognisCoreTests",
            dependencies: ["CognisCore"],
            path: "Tests/CognisCoreTests"
        ),
    ]
)
