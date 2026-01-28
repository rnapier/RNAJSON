// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RNAJSON",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(name: "RNAJSON", targets: ["RNAJSON"]),
        .library(name: "JSONValue", targets: ["JSONValue"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.1"), // Unit test only
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(name: "RNAJSON", dependencies: []),
        .target(name: "JSONValue", dependencies: ["RNAJSON"]),
        .testTarget(
            name: "RNAJSONTests",
            dependencies: ["RNAJSON", "JSONValue",
                           .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")],
            resources: [
                Resource.copy("Resources/json.org"),
                Resource.process("Resources/ditto.json"),
            ]
        ),
        .testTarget(name: "JSONValueTests", dependencies: ["JSONValue"]),
    ]
)
