// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "QuotaBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "QuotaBar", targets: ["QuotaBar"]),
        .executable(name: "QuotaBarCapture", targets: ["QuotaBarCapture"])
    ],
    targets: [
        .executableTarget(
            name: "QuotaBar",
            path: "Sources/QuotaBar"
        ),
        .executableTarget(
            name: "QuotaBarCapture",
            path: "Sources/QuotaBarCapture"
        ),
        .testTarget(
            name: "QuotaBarTests",
            dependencies: ["QuotaBar"],
            path: "Tests/QuotaBarTests"
        )
    ]
)
