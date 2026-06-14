// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
        // Bitcoin support
        .package(url: "https://github.com/BlockchainCommons/BitcoinCore.swift", from: "0.1.0"),
        
        // Solana support
        .package(url: "https://github.com/p2p-org/solana-swift", from: "2.0.0"),
        
        // EVM support
        .package(url: "https://github.com/web3swift-team/web3swift", from: "3.0.0"),
        
        // Flow blockchain support
		.package(url: "https://github.com/13Ophiuchus/flow-swift-macos.git", branch: "main"),

        // Cryptography utilities
        .package(url: "https://github.com/apple/swift-crypto", from: "3.0.0"),
        
        // Big number support for cryptographic operations
        .package(url: "https://github.com/apple/swift-bigint", from: "1.0.0"),
        
        // Async HTTP client for RPC calls
        .package(url: "https://github.com/swift-server/swift-async-http-client", from: "1.0.0"),
        
        // JSON parsing and encoding
        .package(url: "https://github.com/swift-extras/swift-extras-json", from: "0.6.0"),
        
        // Logging
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
        
        // Testing utilities
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "AetherWalletKit",
            dependencies: [
                .product(name: "BitcoinCore", package: "BitcoinCore.swift"),
                .product(name: "SolanaSwift", package: "solana-swift"),
                .product(name: "Web3swift", package: "web3swift"),
                .product(name: "Flow", package: "flow-swift-macos"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "BigInt", package: "swift-bigint"),
                .product(name: "AsyncHTTPClient", package: "swift-async-http-client"),
                .product(name: "ExtrasJSON", package: "swift-extras-json"),
                .product(name: "Logging", package: "swift-log")
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
