import Testing
@testable import AetherWalletKit

@Suite("TransferFlowTokenTarget")
struct TransferFlowTokenTargetTests {
    @Test("cadenceBase64 encodes a valid FlowToken transfer script")
    func cadenceScriptEncodesCorrectly() throws {
        // TODO: instantiate TransferFlowTokenTarget, decode cadenceBase64,
        // assert it contains "FungibleToken" and "FlowToken" imports
    }

    @Test("arguments encode amount as ufix64 and recipient as address")
    func argumentsEncodeCorrectly() throws {
        // TODO: assert Flow.Argument values match expected types/order
    }
}
