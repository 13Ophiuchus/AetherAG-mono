import Testing
import Foundation
import Flow
@testable import AetherWalletKit

@Suite("WalletCore.executeFlowScript")
struct WalletCoreExecuteFlowScriptTests {

    private func makeCore(enableFlow: Bool) -> WalletCore {
        WalletCore(
            keyManager: KeyManagerActor(),
            chainConfigService: ChainConfigurationService(),
            enableBitcoin: false, enableSolana: false, enableEVM: false, enableFlow: enableFlow
        )
    }

    @Test("throws unsupportedOperation when passed a non-Flow ChainConfig")
    func rejectsNonFlowChain() async throws {
        let core = makeCore(enableFlow: true)
        let evmChain = ChainConfig.mockEVM()

        do {
            _ = try await core.executeFlowScript("access(all) fun main(): Int { return 1 }", arguments: [], on: evmChain)
            Issue.record("Expected unsupportedOperation for non-Flow chain")
        } catch WalletError.unsupportedOperation(let message) {
            #expect(message.contains("Flow ChainConfig"))
        }
    }

    @Test("throws unsupportedOperation when Flow module is disabled")
    func rejectsWhenFlowModuleDisabled() async throws {
        let core = makeCore(enableFlow: false)
        let flowChain = ChainConfig.mockFlow()

        do {
            _ = try await core.executeFlowScript("access(all) fun main(): Int { return 1 }", arguments: [], on: flowChain)
            Issue.record("Expected unsupportedOperation when Flow module not enabled")
        } catch WalletError.unsupportedOperation(let message) {
            #expect(message.contains("Flow module not enabled"))
        }
    }

    @Test("default WalletCore initializer enables Flow module")
    func defaultInitializerEnablesFlow() async throws {
        let core = WalletCore(
            keyManager: KeyManagerActor(),
            chainConfigService: ChainConfigurationService()
        )
        let flowChain = ChainConfig.mockFlow()

        // With Flow enabled by default, a non-Flow-chain guard should fire first
        // for an EVM chain, NOT the "Flow module not enabled" guard — proving
        // the flowModule was actually constructed.
        do {
            _ = try await core.executeFlowScript("access(all) fun main(): Int { return 1 }", arguments: [], on: ChainConfig.mockEVM())
            Issue.record("Expected unsupportedOperation for non-Flow chain")
        } catch WalletError.unsupportedOperation(let message) {
            #expect(message.contains("Flow ChainConfig"))
            #expect(!message.contains("Flow module not enabled"))
        }
        _ = flowChain
    }
}
