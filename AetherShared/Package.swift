// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AetherShared",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AetherSharedCore", targets: ["AetherSharedCore"]),
        .library(name: "AetherSharedIdentity", targets: ["AetherSharedIdentity"]),
        .library(name: "AetherSharedProtocols", targets: ["AetherSharedProtocols"]),
        .library(name: "AetherSharedTestSupport", targets: ["AetherSharedTestSupport"]),
    ],
    targets: [
        .target(name: "AetherSharedCore"),
        .target(name: "AetherSharedIdentity", dependencies: ["AetherSharedCore"]),
        .target(name: "AetherSharedProtocols", dependencies: ["AetherSharedCore", "AetherSharedIdentity"]),
        .target(name: "AetherSharedTestSupport", dependencies: ["AetherSharedCore", "AetherSharedIdentity"]),
        .testTarget(name: "AetherSharedCoreTests", dependencies: ["AetherSharedCore"]),
        .testTarget(name: "AetherSharedIdentityTests", dependencies: ["AetherSharedIdentity"]),
        .testTarget(name: "AetherSharedProtocolsTests", dependencies: ["AetherSharedProtocols"]),
    ]
)
