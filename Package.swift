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
        // Everything the phone/ESP32 HUD needs lives in HUD/ so the display
        // side of the project can be read (and reused) on its own.
        .target(
            name: "QuotaBarHUD",
            path: "HUD/macOS",
            resources: [.embedInCode("Resources/hud.html")]
        ),
        .executableTarget(
            name: "QuotaBar",
            dependencies: ["QuotaBarHUD"],
            path: "Sources/QuotaBar"
        ),
        .executableTarget(
            name: "QuotaBarCapture",
            path: "Sources/QuotaBarCapture"
        ),
        .testTarget(
            name: "QuotaBarTests",
            dependencies: ["QuotaBar", "QuotaBarHUD"],
            path: "Tests/QuotaBarTests"
        )
    ]
)
