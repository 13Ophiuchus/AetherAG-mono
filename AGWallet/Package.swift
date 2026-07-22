// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AetherWalletKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AetherWalletKit",
            targets: ["AetherWalletKit"]
        ),
    ],
    dependencies: [
        .package(path: "../AetherShared"),
        .package(path: "../solana-swift-patched"),
        .package(path: "../web3swift-patched"),
        .package(url: "https://github.com/13Ophiuchus/flow-swift-macos.git", revision: "9a811b30d19bde7bab7cc35c872c3b98a3b03536"),
        .package(url: "https://github.com/apple/swift-crypto", "1.0.0"..<"5.0.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMinor(from: "5.4.0")),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.19.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-json", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.0.0"),
        .package(url: "https://github.com/21-DOT-DEV/swift-secp256k1", from: "0.21.1"),
    ],
    targets: [
        .target(
            name: "AetherWalletKit",
            dependencies: [
                .product(name: "AetherSharedProtocols", package: "AetherShared"),
                .product(name: "SolanaSwift", package: "solana-swift-patched"),
                .product(name: "web3swift", package: "web3swift-patched"),
                .product(name: "Flow", package: "flow-swift-macos"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "P256K", package: "swift-secp256k1"),
            ],
            path: "Sources/AetherWalletKit"
        ),
        .testTarget(
            name: "AetherWalletKitTests",
            dependencies: [
                "AetherWalletKit",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/AetherWalletKitTests"
        ),
    ]
)
