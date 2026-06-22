// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "spm-reclaim",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "spm-reclaim", targets: ["SPMReclaim"])
    ],
    targets: [
        .executableTarget(name: "SPMReclaim", path: "Sources/SPMReclaim")
    ]
)
