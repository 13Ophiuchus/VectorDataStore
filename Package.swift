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
		// Core components
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
		.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
	],
	targets: [
		// Core modules
		.target(
			name: "VectorDataStore",
			dependencies: [
				.product(name: "Logging", package: "swift-log"),
				.product(name: "NIO", package: "swift-nio"),
				.product(name: "NIOHTTP1", package: "swift-nio"),
				.product(name: "Logging", package: "swift-log"),
				.product(name: "Crypto", package: "swift-crypto")
			],
			path: "Sources/VectorDataStore",
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency"),
				.enableUpcomingFeature("ExistentialAny"),
				.enableUpcomingFeature("InferSendableFromCaptures")
			]
		),
		// Test targets
		.testTarget(
			name: "VectorDataStoreTests",
			dependencies: ["VectorDataStore"],
			path: "Tests/VectorDataStoreTests"
		),
	]
)
