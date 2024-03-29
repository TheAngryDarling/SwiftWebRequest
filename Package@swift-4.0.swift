// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebRequest",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "WebRequest",
            targets: ["WebRequest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/TheAngryDarling/SwiftLittleWebServer.git",
                 .exact( "0.1.6")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "WebRequest",
            dependencies: []),
        .testTarget(
            name: "WebRequestTests",
            dependencies: ["WebRequest", "LittleWebServer"]),
    ]
)
