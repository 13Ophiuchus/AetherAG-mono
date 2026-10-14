@testable import AetherWalletKit
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing

@Suite("EVMModule")
struct EVMModuleTests {
    private func makeModule() -> EVMModule {
        EVMModule(keyManager: KeyManagerActor(storageProvider: InMemoryKeyStorageProvider()))
    }

    @Test("getBalance fails with keychainError when no master key is stored")
    func testGetBalance() async throws {
        let evmModule = makeModule()
        let asset = CryptoAsset.mockEthereum()

        do {
            _ = try await evmModule.getBalance(for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for EVM getBalance")
        } catch let WalletError.keychainError(message) {
            #expect(message == "Private key not found for Ethereum")
        }
    }

    @Test("send fails with keychainError when no master key is stored")
    func sendTransaction() async throws {
        let evmModule = makeModule()
        let asset = CryptoAsset.mockEthereum()
        let amount = 0.01
        let recipient = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb9"

        do {
            _ = try await evmModule.send(amount: amount, to: recipient, for: asset)
            Issue.record("Expected keychainError(\"Master key not found\") for EVM send")
        } catch let WalletError.keychainError(message) {
            #expect(message == "Private key not found for Ethereum")
        }
    }

    @Test("signMessage fails with keychainError when no master key is stored")
    func testSignMessage() async throws {
        let evmModule = makeModule()
        let message = "AetherWalletKit test message"
        let chain = ChainConfig.mockEthereumChain()

        do {
            _ = try await evmModule.signMessage(message, on: chain)
            Issue.record("Expected keychainError(\"Master key not found\") for EVM signMessage")
        } catch let WalletError.keychainError(message) {
            #expect(message == "Private key not found for Ethereum")
        }
    }

    @Test("getTransactionHistory returns empty array when no indexer endpoint is configured")
    func testGetTransactionHistoryNoIndexer() async throws {
        let evmModule = makeModule()
        let chain = ChainConfig.mockEthereumChain()

        let history = try await evmModule.getTransactionHistory(for: chain)
        #expect(history.isEmpty)
    }
}

private actor EVMIndexerHTTPClientStub: EVMIndexerHTTPClient {
    private let data: Data
    private let response: URLResponse

    init(
        data: Data,
        statusCode: Int = 200,
        url: URL = URL(string: "https://indexer.example/api")!
    ) {
        self.data = data
        response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        (data, response)
    }
}

private func makeEtherscanTransactionResponse(
    value: String = "1000000000000000000",
    gasPrice: String = "20000000000",
    gas: String = "21000",
    nonce: String = "7",
    blockNumber: String = "21000000",
    timeStamp: String = "1728000000"
) throws -> Data {
    let payload: [String: Any] = [
        "status": "1",
        "message": "OK",
        "result": [[
            "hash": "0xabc123",
            "from": "0x0000000000000000000000000000000000000001",
            "to": "0x0000000000000000000000000000000000000002",
            "value": value,
            "gasPrice": gasPrice,
            "gas": gas,
            "nonce": nonce,
            "blockNumber": blockNumber,
            "timeStamp": timeStamp,
        ]],
    ]

    return try JSONSerialization.data(
        withJSONObject: payload,
        options: [.sortedKeys]
    )
}

@Suite("EVM indexer transaction decoding")
struct EVMIndexerClientTests {
    private let baseURL = URL(string: "https://indexer.example/api")!

    private func makeClient(
        responseData: Data
    ) -> EVMIndexerClient {
        EVMIndexerClient(
            baseURL: baseURL,
            session: EVMIndexerHTTPClientStub(data: responseData)
        )
    }

    @Test("Maps valid Etherscan transaction fields without coercion")
    func mapsValidTransaction() async throws {
        let client = makeClient(
            responseData: try makeEtherscanTransactionResponse()
        )

        let transactions = try await client.getTransactionHistory(
            for: "0x0000000000000000000000000000000000000001",
            chainId: 1
        )

        #expect(transactions.count == 1)

        guard case let .evm(transaction) = try #require(transactions.first) else {
            Issue.record("Expected an EVM transaction.")
            return
        }

        #expect(transaction.hash == "0xabc123")
        #expect(transaction.value == "1000000000000000000")
        #expect(transaction.gasPrice == "20000000000")
        #expect(transaction.gasLimit == "21000")
        #expect(transaction.nonce == 7)
        #expect(transaction.chainId == 1)
        #expect(transaction.blockNumber == 21_000_000)
        #expect(transaction.timestamp == Date(timeIntervalSince1970: 1_728_000_000))
    }

    @Test(
        "Rejects malformed required decimal fields",
        arguments: [
            ("value", "0x10"),
            ("value", "-1"),
            ("value", ""),
            ("gasPrice", "ten"),
            ("gas", ""),
            ("nonce", "1.5"),
            ("timeStamp", "invalid"),
        ]
    )
    func rejectsMalformedRequiredFields(
        field: String,
        malformedValue: String
    ) async throws {
        var fields = [
            "value": "1",
            "gasPrice": "2",
            "gas": "3",
            "nonce": "4",
            "blockNumber": "5",
            "timeStamp": "1728000000",
        ]
        fields[field] = malformedValue

        let client = makeClient(
            responseData: try makeEtherscanTransactionResponse(
                value: fields["value"]!,
                gasPrice: fields["gasPrice"]!,
                gas: fields["gas"]!,
                nonce: fields["nonce"]!,
                blockNumber: fields["blockNumber"]!,
                timeStamp: fields["timeStamp"]!
            )
        )

        do {
            _ = try await client.getTransactionHistory(
                for: "0x0000000000000000000000000000000000000001",
                chainId: 1
            )
            Issue.record("Expected malformed \(field) to be rejected.")
        } catch let WalletError.invalidResponse(message) {
            #expect(message.contains("transaction 0xabc123"))
        }
    }

    @Test("Maps an empty block number to nil for a pending transaction")
    func mapsEmptyBlockNumberToNil() async throws {
        let client = makeClient(
            responseData: try makeEtherscanTransactionResponse(
                blockNumber: ""
            )
        )

        let transactions = try await client.getTransactionHistory(
            for: "0x0000000000000000000000000000000000000001",
            chainId: 1
        )

        guard case let .evm(transaction) = try #require(transactions.first) else {
            Issue.record("Expected an EVM transaction.")
            return
        }

        #expect(transaction.blockNumber == nil)
    }

    @Test(
        "Rejects overflow in numeric transaction fields",
        arguments: ["nonce", "blockNumber", "timeStamp"]
    )
    func rejectsOverflow(
        field: String
    ) async throws {
        let overflow = "999999999999999999999999999999999999999999"

        var fields = [
            "nonce": "4",
            "blockNumber": "5",
            "timeStamp": "1728000000",
        ]
        fields[field] = overflow

        let client = makeClient(
            responseData: try makeEtherscanTransactionResponse(
                nonce: fields["nonce"]!,
                blockNumber: fields["blockNumber"]!,
                timeStamp: fields["timeStamp"]!
            )
        )

        do {
            _ = try await client.getTransactionHistory(
                for: "0x0000000000000000000000000000000000000001",
                chainId: 1
            )
            Issue.record("Expected overflowing \(field) to be rejected.")
        } catch let WalletError.invalidResponse(message) {
            #expect(message.contains("transaction 0xabc123"))
        }
    }
}
