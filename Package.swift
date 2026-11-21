// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OutIP",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "OutIPCore"),
        .testTarget(name: "OutIPCoreTests", dependencies: ["OutIPCore"]),
    ],
    swiftLanguageModes: [.v6]
)
