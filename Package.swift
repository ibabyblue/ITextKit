// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ITextKit",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "ITextKit", targets: ["ITextKit"]),
    ],
    targets: [
        .target(name: "ITextKit"),
        .testTarget(
            name: "ITextKitCoreTests",
            dependencies: ["ITextKit"]
        ),
        .testTarget(
            name: "ITextKitSwiftUITests",
            dependencies: ["ITextKit"]
        ),
        .testTarget(
            name: "ITextKitUIKitTests",
            dependencies: ["ITextKit"]
        ),
    ]
)
