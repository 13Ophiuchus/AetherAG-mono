import Testing
import Foundation
import Flow
import Security
@testable import AetherWalletKit

@Suite("Flow Account Creation - Testnet Only")
struct FlowAccountCreationTests {

    @Test(.enabled(if: ProcessInfo.processInfo.environment["FLOW_TESTNET_INTEGRATION"] == "1"))
    func createFlowAccount_succeedsOnTestnet() async throws {
        guard let issuerPrivateKeyHex = ProcessInfo.processInfo.environment["FLOW_TESTNET_ISSUER_KEY"] else {
            Issue.record("FLOW_TESTNET_ISSUER_KEY not set — skipping.")
            return
        }
        guard let issuerAddressHex = ProcessInfo.processInfo.environment["FLOW_TESTNET_ISSUER_ADDRESS"] else {
            Issue.record("FLOW_TESTNET_ISSUER_ADDRESS not set — skipping.")
            return
        }
        guard let keyData = Data(hexEncoded: issuerPrivateKeyHex) else {
            Issue.record("FLOW_TESTNET_ISSUER_KEY is not valid hex")
            return
        }

        let keychainIdentifier = "flowTestnetIssuerKey_integrationTest"
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainIdentifier,
            kSecValueData as String: keyData
        ]
        SecItemDelete(addQuery as CFDictionary)
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        #expect(addStatus == errSecSuccess)
        defer { SecItemDelete(addQuery as CFDictionary) }

        let issuerAddress = Flow.Address(hex: issuerAddressHex)
        let issuerConfig = FlowIssuerConfig(
            address: issuerAddress,
            keyIndex: 0,
            proposalKey: Flow.TransactionProposalKey(address: issuerAddress, keyIndex: 0),
            keychainIdentifier: keychainIdentifier
        )

        let keyManager = KeyManagerActor(storageProvider: InMemoryKeyStorageProvider())
        _ = try await keyManager.resetMasterKey(requiresBiometrics: false)

        let address = try await keyManager.createFlowAccount(issuerConfig: issuerConfig, network: .testnet)

        #expect(!address.isEmpty)

        let normalized = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        #expect(normalized.count == 16)
        #expect(normalized.allSatisfy { $0.isHexDigit })

        let url = try #require(URL(string: "https://rest-testnet.onflow.org/v1/accounts/\(normalized)?expand=keys"))
        var firstKey: [String: Any]?
        for _ in 0..<5 {
            let (data, response) = try await URLSession.shared.data(from: url)
            if (response as? HTTPURLResponse)?.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let keys = json["keys"] as? [[String: Any]],
               let first = keys.first {
                firstKey = first
                break
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        let key = try #require(firstKey, "New account \(normalized) has no readable key on testnet")
        #expect(key["signing_algorithm"] as? String == "ECDSA_P256")
        #expect(key["hashing_algorithm"] as? String == "SHA3_256")
        #expect(key["weight"] as? String == "1000")
        #expect(key["revoked"] as? Bool == false)
    }
}

private extension Data {
    init?(hexEncoded hex: String) {
        let cleaned = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard cleaned.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else { return nil }
            bytes.append(byte)
            index = nextIndex
        }
        self = Data(bytes)
    }
}
