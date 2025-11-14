// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "VectorDataStore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v9),
        .tvOS(.v15)
    ],
    products: [
        .library(name: "VectorDataStore", targets: ["VectorDataStore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.4"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.86.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.27.0"),
        .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.23.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.1"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.4"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/outblock/flow-swift.git", from: "0.4.0"),
        .package(url: "https://github.com/apple/swift-corelibs-coreml.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-corelibs-foundationnetworking.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-corelibs-testing.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "VectorDataStore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Flow", package: "flow-swift"),
                .product(name: "CoreML", package: "swift-corelibs-coreml"),
                .product(name: "FoundationNetworking", package: "swift-corelibs-foundationnetworking"),
                .product(name: "SwiftTesting", package: "swift-corelibs-testing.git")
            ],
            path: "Sources/VectorDataStore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InferSendableFromCaptures")
            ]
        ),
        .target(name: "SwiftDataStyleStore",
                dependencies: ["VectorDataStore"],
                path: "Sources/SwiftDataStyleStore",
                swiftSettings: [.define("CAN_IMPORT_SWIFT_DATA")],
                exclude: ["**/*.swift"]),
        .testTarget(
            name: "AppTest",
            dependencies: ["VectorDataStore"],
            path: "Tests/AppTest"
        )
    ]
)
