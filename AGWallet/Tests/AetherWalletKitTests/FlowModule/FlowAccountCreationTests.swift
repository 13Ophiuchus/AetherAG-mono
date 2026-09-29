import Testing
import Foundation
import Flow
@testable import AetherWalletKit

@Suite("Flow Account Creation - Testnet Only")
struct FlowAccountCreationTests {

    // WARNING: gate this behind an env var so it never runs against
    // mainnet accidentally in CI.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["FLOW_TESTNET_INTEGRATION"] == "1"))
    func createFlowAccount_succeedsOnTestnet() async throws {
        // TODO: populate with a funded testnet issuer account.
        // Never hardcode a real private key here — load from environment
        // or a local, gitignored .env file for local runs only.
        guard let issuerPrivateKeyHex = ProcessInfo.processInfo.environment["FLOW_TESTNET_ISSUER_KEY"] else {
            Issue.record("FLOW_TESTNET_ISSUER_KEY not set — skipping.")
            return
        }
        _ = issuerPrivateKeyHex
        // let config = FlowIssuerConfig(...)
        // let gateway = LiveFlowGateway(chainID: .testnet)
        // let address = try await keyManager.createFlowAccount(issuerConfig: config, flowGateway: gateway, network: .testnet)
        // #expect(!address.isEmpty)
    }
}
