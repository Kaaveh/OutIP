// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "OutIP",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "OutIPCore"),
        .executableTarget(
            name: "OutIP",
            dependencies: ["OutIPCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "OutIPCoreTests", dependencies: ["OutIPCore"]),
    ],
    swiftLanguageModes: [.v6]
)
