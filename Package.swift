// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RNAJSON",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "RNAJSON",
            targets: ["RNAJSON"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.0.2"),    // Unit test only

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(name: "RNAJSON", dependencies: [
        ]),
        .testTarget(
            name: "RNAJSONTests",
            dependencies: ["RNAJSON",
                           .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            resources: [
                Resource.copy("Resources/json.org"),
                Resource.process("Resources/ditto.json"),
            ]
        ),
    ]
)
