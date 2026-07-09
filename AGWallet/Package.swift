// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AetherWalletKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AetherWalletKit",
            targets: ["AetherWalletKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/p2p-org/solana-swift", from: "2.0.0"),
        .package(url: "https://github.com/web3swift-team/web3swift", from: "3.0.0"),
        .package(url: "https://github.com/13Ophiuchus/flow-swift-macos.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-crypto", "1.0.0"..<"5.0.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", .upToNextMinor(from: "5.4.0")),
        .package(url: "https://github.com/swift-server/async-http-client", from: "1.19.0"),
        .package(url: "https://github.com/swift-extras/swift-extras-json", from: "0.6.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "AetherWalletKit",
            dependencies: [
                .product(name: "SolanaSwift", package: "solana-swift"),
                .product(name: "web3swift", package: "web3swift"),
                .product(name: "Flow", package: "flow-swift-macos"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BigInt", package: "BigInt"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                .product(name: "Logging", package: "swift-log"),
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
