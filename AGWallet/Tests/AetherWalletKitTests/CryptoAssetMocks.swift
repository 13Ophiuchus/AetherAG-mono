import Foundation
@testable import AetherWalletKit

extension CryptoAsset {
    static func mockBitcoin() -> CryptoAsset {
        CryptoAsset(
            name: "Bitcoin",
            symbol: "BTC",
            decimals: 8,
            contractAddress: nil,
            chainConfig: ChainConfig(
                chainId: "bitcoin",
                name: "Bitcoin",
                type: .bitcoin,
                rpcEndpoints: [URL(string: "http://localhost:8332")!],
                derivationPath: "m/44'/0'/0'/0/0",
                nativeAssetSymbol: "BTC"
            ),
            balance: 1.23
        )
    }

    static func mockEthereum() -> CryptoAsset {
        CryptoAsset(
            name: "Ethereum",
            symbol: "ETH",
            decimals: 18,
            contractAddress: nil,
            chainConfig: ChainConfig(
                chainId: "1",
                name: "Ethereum",
                type: .evm,
                rpcEndpoints: [URL(string: "https://mainnet.infura.io/v3/YOUR_PROJECT_ID")!],
                derivationPath: "m/44'/60'/0'/0/0",
                nativeAssetSymbol: "ETH"
            ),
            balance: 0.42
        )
    }

    static func mockSolana() -> CryptoAsset {
        CryptoAsset(
            name: "Solana",
            symbol: "SOL",
            decimals: 9,
            contractAddress: nil,
            chainConfig: ChainConfig(
                chainId: "solana",
                name: "Solana",
                type: .solana,
                rpcEndpoints: [URL(string: "https://api.mainnet-beta.solana.com")!],
                derivationPath: "m/44'/501'/0'/0'",
                nativeAssetSymbol: "SOL"
            ),
            balance: 5.67
        )
    }

    static func mockFlow() -> CryptoAsset {
        CryptoAsset(
            name: "Flow",
            symbol: "FLOW",
            decimals: 8,
            contractAddress: nil,
            chainConfig: ChainConfig(
                chainId: "flow-mainnet",
                name: "Flow",
                type: .flow,
                rpcEndpoints: [URL(string: "https://rest-mainnet.onflow.org/v1")!],
                derivationPath: "m/44'/539'/0'/0/0",
                nativeAssetSymbol: "FLOW"
            ),
            balance: 10.0
        )
    }
}
