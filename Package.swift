// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "vr",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "vr", targets: ["vr"])
    ],
    targets: [
        .executableTarget(
            name: "vr"
        )
    ]
)
