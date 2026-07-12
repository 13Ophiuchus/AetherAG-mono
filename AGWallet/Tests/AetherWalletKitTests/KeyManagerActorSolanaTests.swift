import Foundation
import Testing
@testable import AetherWalletKit

@Suite("KeyManagerActor Solana signing")
struct KeyManagerActorSolanaTests {

    private func solanaTestChain() -> ChainConfig {
        ChainConfig(
            chainId: "solana",
            name: "Solana",
            type: .solana,
            rpcEndpoints: [URL(string: "https://api.devnet.solana.com")!],
            derivationPath: "m/44'/501'/0'/0'",
            nativeAssetSymbol: "SOL"
        )
    }

    private func makeManagerWithMasterKey() async throws -> KeyManagerActor {
        let manager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        let mnemonic = try await manager.generateMnemonic()
        let masterKey = try await manager.generateMasterPrivateKey(from: mnemonic)
        try await manager.storePrivateKey(masterKey, for: "masterKey", requiresBiometrics: false)
        return manager
    }

    @Test("solanaAddress(for:) returns a valid base58 address after key storage")
    func testSolanaAddressDerivation() async throws {
        let manager = try await makeManagerWithMasterKey()
        let chain = solanaTestChain()

        let address = try await manager.solanaAddress(for: chain)

        #expect(!address.isEmpty)
        #expect(address.count >= 32 && address.count <= 44)
    }

    @Test("signSolanaMessage produces a non-empty deterministic signature for the same key and message")
    func testSolanaMessageSigningIsDeterministic() async throws {
        let manager = try await makeManagerWithMasterKey()
        let chain = solanaTestChain()

        let signature1 = try await manager.signSolanaMessage("hello world", chain: chain)
        let signature2 = try await manager.signSolanaMessage("hello world", chain: chain)

        #expect(signature1 == signature2)
        #expect(!signature1.isEmpty)
    }

    @Test("signSolanaMessage produces different signatures for different messages")
    func testSolanaMessageSigningDiffersByMessage() async throws {
        let manager = try await makeManagerWithMasterKey()
        let chain = solanaTestChain()

        let signature1 = try await manager.signSolanaMessage("hello world", chain: chain)
        let signature2 = try await manager.signSolanaMessage("goodbye world", chain: chain)

        #expect(signature1 != signature2)
    }

    private func mockTransferTransaction(from senderAddress: String, to recipientAddress: String) -> SolanaTransaction {
        let systemProgramId = "11111111111111111111111111111111"
        let lamports: UInt64 = 1_000_000
        let lamportsLE = withUnsafeBytes(of: lamports.littleEndian) { Data($0) }
        let transferDiscriminator: [UInt8] = [2, 0, 0, 0]
        var instructionData = Data(transferDiscriminator)
        instructionData.append(lamportsLE)
        let dataHex = instructionData.map { String(format: "%02x", $0) }.joined()

        let instruction = SolanaInstruction(
            programId: systemProgramId,
            accounts: [
                SolanaAccountMeta(publicKey: senderAddress, isSigner: true, isWritable: true),
                SolanaAccountMeta(publicKey: recipientAddress, isSigner: false, isWritable: true)
            ],
            data: dataHex
        )

        return SolanaTransaction(
            signature: "",
            recentBlockhash: "EETcHmMwaUhi9jSHVdaUyKWDavcYCJZ8SxLXTfRR1qud",
            instructions: [instruction],
            fee: 0.000005,
            slot: nil,
            timestamp: Date()
        )
    }

    @Test("signSolanaTransfer produces a non-empty base58 signature for a native SOL transfer")
    func testSolanaTransferSigning() async throws {
        let manager = try await makeManagerWithMasterKey()
        let chain = solanaTestChain()
        let senderAddress = try await manager.solanaAddress(for: chain)
        let recipientAddress = "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM"

        let transaction = mockTransferTransaction(from: senderAddress, to: recipientAddress)
        let signature = try await manager.signSolanaTransfer(transaction, chain: chain)

        #expect(!signature.isEmpty)
    }

    @Test("signSolanaTransfer is deterministic for the same transaction and key")
    func testSolanaTransferSigningIsDeterministic() async throws {
        let manager = try await makeManagerWithMasterKey()
        let chain = solanaTestChain()
        let senderAddress = try await manager.solanaAddress(for: chain)
        let recipientAddress = "9WzDXwBbmkg8ZTbNMqUxvQRAyrZzDsGYdLVL9zYtAWWM"

        let transaction = mockTransferTransaction(from: senderAddress, to: recipientAddress)
        let signature1 = try await manager.signSolanaTransfer(transaction, chain: chain)
        let signature2 = try await manager.signSolanaTransfer(transaction, chain: chain)

        #expect(signature1 == signature2)
    }
}
