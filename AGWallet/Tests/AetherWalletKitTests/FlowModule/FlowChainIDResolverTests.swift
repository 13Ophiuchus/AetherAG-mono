import Testing
import Foundation
import Flow
@testable import AetherWalletKit

@Suite("FlowChainIDResolver")
struct FlowChainIDResolverTests {

    private func makeChainConfig(network: ChainNetwork) -> ChainConfig {
        ChainConfig(
            chainId: "flow-\(network.rawValue)",
            name: "Flow",
            type: .flow,
            rpcEndpoints: [URL(string: "https://rest-\(network.rawValue).onflow.org/v1")!],
            derivationPath: "m/44'/539'/0'/0/0",
            nativeAssetSymbol: "FLOW",
            network: network
        )
    }

    @Test("mainnet ChainConfig resolves to Flow.ChainID.mainnet")
    func mainnetResolves() {
        let config = makeChainConfig(network: .mainnet)
        #expect(FlowChainIDResolver.resolve(config) == .mainnet)
    }

    @Test("testnet ChainConfig resolves to Flow.ChainID.testnet")
    func testnetResolves() {
        let config = makeChainConfig(network: .testnet)
        #expect(FlowChainIDResolver.resolve(config) == .testnet)
    }

    @Test("non-testnet networks (signet, regtest, devnet, local) fall back to Flow.ChainID.mainnet")
    func nonTestnetFallsBackToMainnet() {
        for network: ChainNetwork in [.signet, .regtest, .devnet, .local] {
            let config = makeChainConfig(network: network)
            #expect(FlowChainIDResolver.resolve(config) == .mainnet, "Expected \(network) to fall back to mainnet")
        }
    }
}
