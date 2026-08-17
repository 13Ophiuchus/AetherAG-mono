import Testing
import Foundation
import Flow
@testable import AetherWalletKit

@Suite("FlowTokenEventType")
struct FlowTokenEventTypeTests {

    @Test("mainnet uses canonical FlowToken contract address")
    func mainnetContractAddress() {
        #expect(FlowTokenEventType.contractAddress(chainID: .mainnet) == "1654653399040a61")
        #expect(FlowTokenEventType.deposited(chainID: .mainnet) == "A.1654653399040a61.FlowToken.TokensDeposited")
        #expect(FlowTokenEventType.withdrawn(chainID: .mainnet) == "A.1654653399040a61.FlowToken.TokensWithdrawn")
    }

    @Test("testnet uses canonical FlowToken contract address")
    func testnetContractAddress() {
        #expect(FlowTokenEventType.contractAddress(chainID: .testnet) == "7e60df042a9c0868")
        #expect(FlowTokenEventType.deposited(chainID: .testnet) == "A.7e60df042a9c0868.FlowToken.TokensDeposited")
        #expect(FlowTokenEventType.withdrawn(chainID: .testnet) == "A.7e60df042a9c0868.FlowToken.TokensWithdrawn")
    }
}

@Suite("FlowTransactionHistoryMatcher")
struct FlowTransactionHistoryMatcherTests {

    let watched = "0x01"

    @Test("deposit event matches when toField equals watched address")
    func depositMatchesOnTo() {
        let result = FlowTransactionHistoryMatcher.matches(
            isDeposit: true, toField: watched, fromField: nil, watchedAddress: watched
        )
        #expect(result == true)
    }

    @Test("deposit event does not match when toField differs")
    func depositDoesNotMatchOnDifferentTo() {
        let result = FlowTransactionHistoryMatcher.matches(
            isDeposit: true, toField: "0x02", fromField: nil, watchedAddress: watched
        )
        #expect(result == false)
    }

    @Test("deposit event does not match when toField is nil, regardless of fromField")
    func depositDoesNotMatchOnNilTo() {
        let result = FlowTransactionHistoryMatcher.matches(
            isDeposit: true, toField: nil, fromField: watched, watchedAddress: watched
        )
        #expect(result == false)
    }

    @Test("withdrawn event matches when fromField equals watched address")
    func withdrawnMatchesOnFrom() {
        let result = FlowTransactionHistoryMatcher.matches(
            isDeposit: false, toField: nil, fromField: watched, watchedAddress: watched
        )
        #expect(result == true)
    }

    @Test("withdrawn event does not match when fromField differs")
    func withdrawnDoesNotMatchOnDifferentFrom() {
        let result = FlowTransactionHistoryMatcher.matches(
            isDeposit: false, toField: nil, fromField: "0x03", watchedAddress: watched
        )
        #expect(result == false)
    }

    @Test("withdrawn event does not match when fromField is nil, regardless of toField")
    func withdrawnDoesNotMatchOnNilFrom() {
        let result = FlowTransactionHistoryMatcher.matches(
            isDeposit: false, toField: watched, fromField: nil, watchedAddress: watched
        )
        #expect(result == false)
    }
}
