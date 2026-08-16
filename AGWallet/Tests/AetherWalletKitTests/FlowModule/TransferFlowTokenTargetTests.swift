import Testing
import Foundation
@testable import AetherWalletKit

@Suite("TransferFlowTokenTarget")
struct TransferFlowTokenTargetTests {

    @Test("cadenceBase64 encodes a valid FlowToken transfer script")
    func cadenceScriptEncodesCorrectly() throws {
        let target = TransferFlowTokenTarget(to: Flow.Address(hex: "0x01"), amount: 1.5)
        let decodedData = try #require(Data(base64Encoded: target.cadenceBase64))
        let script = try #require(String(data: decodedData, encoding: .utf8))

        #expect(script.contains("import FungibleToken"))
        #expect(script.contains("import FlowToken"))
        #expect(script.contains("transaction(amount: UFix64, to: Address)"))
        #expect(script.contains("vaultRef.withdraw(amount: amount)"))
        #expect(script.contains("receiverRef.deposit(from: <-self.sentVault)"))
    }

    @Test("arguments encode amount as ufix64 and recipient as address, in order")
    func argumentsEncodeCorrectly() throws {
        let recipient = Flow.Address(hex: "0x02")
        let target = TransferFlowTokenTarget(to: recipient, amount: 2.25)
        let args = target.arguments

        #expect(args.count == 2)
        if case let .ufix64(value) = args[0].value {
            #expect(value == Decimal(2.25))
        } else {
            Issue.record("Expected first argument to be .ufix64")
        }
        if case let .address(value) = args[1].value {
            #expect(value == recipient)
        } else {
            Issue.record("Expected second argument to be .address")
        }
    }

    @Test("type is transaction and returnType is String")
    func metadataIsCorrect() throws {
        let target = TransferFlowTokenTarget(to: Flow.Address(hex: "0x03"), amount: 1.0)
        #expect(target.type == .transaction)
        #expect(target.returnType == String.self)
    }
}
