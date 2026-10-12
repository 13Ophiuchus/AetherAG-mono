@testable import AetherWalletKit
import Foundation
import Testing

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@Suite("EVMIndexerClient")
struct EVMIndexerClientTests {
    @Test("Maps valid Etherscan transaction metadata")
    func mapsValidTransactionMetadata() async throws {
        let client = makeClient(
            nonce: "7",
            blockNumber: "123456",
            timestamp: "1720000000"
        )

        let transactions = try await client.getTransactionHistory(
            for: "0xabc",
            chainId: 1
        )

        #expect(transactions.count == 1)

        guard case let .evm(transaction) = try #require(transactions.first) else {
            Issue.record("Expected an EVM transaction.")
            return
        }

        #expect(transaction.hash == "0xtransaction")
        #expect(transaction.from == "0xsender")
        #expect(transaction.to == "0xrecipient")
        #expect(transaction.value == "123000000000000000")
        #expect(transaction.gasPrice == "42000000000")
        #expect(transaction.gasLimit == "21000")
        #expect(transaction.nonce == 7)
        #expect(transaction.chainId == 1)
        #expect(transaction.blockNumber == 123456)
        #expect(
            transaction.timestamp == Date(timeIntervalSince1970: 1_720_000_000)
        )
    }

    @Test("Maps an empty block number as pending")
    func mapsEmptyBlockNumberAsNil() async throws {
        let client = makeClient(
            nonce: "7",
            blockNumber: "",
            timestamp: "1720000000"
        )

        let transactions = try await client.getTransactionHistory(
            for: "0xabc",
            chainId: 1
        )

        guard case let .evm(transaction) = try #require(transactions.first) else {
            Issue.record("Expected an EVM transaction.")
            return
        }

        #expect(transaction.blockNumber == nil)
        #expect(
            transaction.timestamp == Date(timeIntervalSince1970: 1_720_000_000)
        )
    }

    @Test(
        "Rejects malformed or negative numeric metadata",
        arguments: [
            ("not-a-number", "123456", "1720000000"),
            ("-1", "123456", "1720000000"),
            ("7", "not-a-number", "1720000000"),
            ("7", "-1", "1720000000"),
            ("7", "123456", "not-a-number"),
            ("7", "123456", "-1"),
        ]
    )
    func rejectsInvalidNumericMetadata(
        nonce: String,
        blockNumber: String,
        timestamp: String
    ) async throws {
        let client = makeClient(
            nonce: nonce,
            blockNumber: blockNumber,
            timestamp: timestamp
        )

        do {
            _ = try await client.getTransactionHistory(for: "0xabc", chainId: 1)
            Issue.record("Expected invalid numeric metadata to throw.")
        } catch let WalletError.chainConfigurationError(message) {
            #expect(
                message.hasPrefix(
                    "Invalid non-negative integer for indexer field:"
                )
            )
        }
    }

    private func makeClient(
        nonce: String,
        blockNumber: String,
        timestamp: String
    ) -> EVMIndexerClient {
        let identifier = UUID().uuidString
        let url = URL(string: "https://indexer.example/\(identifier)")!
        StubURLProtocol.register(
            body: responseBody(
                nonce: nonce,
                blockNumber: blockNumber,
                timestamp: timestamp
            ),
            forPath: "/\(identifier)"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return EVMIndexerClient(
            baseURL: url,
            session: URLSession(configuration: configuration)
        )
    }

    private func responseBody(
        nonce: String,
        blockNumber: String,
        timestamp: String
    ) -> Data {
        let transaction: [String: Any] = [
            "hash": "0xtransaction",
            "from": "0xsender",
            "to": "0xrecipient",
            "value": "123000000000000000",
            "gasPrice": "42000000000",
            "gas": "21000",
            "nonce": nonce,
            "blockNumber": blockNumber,
            "timeStamp": timestamp,
        ]

        let payload: [String: Any] = [
            "status": "1",
            "message": "OK",
            "result": [transaction],
        ]

        return try! JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        )
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [String: Data] = [:]

    static func register(body: Data, forPath path: String) {
        lock.lock()
        responses[path] = body
        lock.unlock()
    }

    private static func response(forPath path: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return responses.removeValue(forKey: path)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "indexer.example"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let url = request.url,
            let body = Self.response(forPath: url.path),
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
