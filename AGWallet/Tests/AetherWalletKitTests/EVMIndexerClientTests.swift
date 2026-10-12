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
            body: responseBody(
                nonce: "7",
                blockNumber: "123456",
                timestamp: "1720000000"
            )
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
            body: responseBody(
                nonce: "7",
                blockNumber: "",
                timestamp: "1720000000"
            )
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
            body: responseBody(
                nonce: nonce,
                blockNumber: blockNumber,
                timestamp: timestamp
            )
        )

        await expectConfigurationError(
            from: client,
            expectedMessagePrefix:
                "Invalid non-negative integer for indexer field:"
        )
    }

    @Test(
        "Rejects non-success HTTP status responses",
        arguments: [
            (401, "Invalid API Key", "401"),
            (429, "Max rate limit reached", "429"),
            (500, "Indexer unavailable", "500"),
        ]
    )
    func rejectsNonSuccessHTTPStatuses(
        statusCode: Int,
        body: String,
        expectedStatus: String
    ) async throws {
        let client = makeClient(
            statusCode: statusCode,
            body: Data(body.utf8)
        )

        await expectConfigurationError(
            from: client,
            expectedMessagePrefix:
                "Indexer request failed (\(expectedStatus)): \(body)"
        )
    }

    @Test("Rejects provider error with transactions")
    func rejectsProviderErrorWithTransactions() async throws {
        let client = makeClient(
            body: jsonData([
                "status": "0",
                "message": "NOTOK",
                "result": [[
                    "hash": "0xtransaction",
                    "from": "0xsender",
                    "to": "0xrecipient",
                    "value": "0",
                    "gasPrice": "0",
                    "gas": "21000",
                    "nonce": "0",
                    "blockNumber": "1",
                    "timeStamp": "1720000000",
                ]],
            ])
        )

        await expectConfigurationError(
            from: client,
            expectedMessagePrefix: "Indexer error: NOTOK"
        )
    }

    @Test("Maps provider status zero with empty result to empty history")
    func mapsProviderStatusZeroWithEmptyResultToEmptyHistory() async throws {
        let client = makeClient(
            body: jsonData([
                "status": "0",
                "message": "No transactions found",
                "result": [],
            ])
        )

        let transactions = try await client.getTransactionHistory(
            for: "0xabc",
            chainId: 1
        )

        #expect(transactions.isEmpty)
    }

    @Test("Maps successful empty result to empty history")
    func mapsSuccessfulEmptyResultToEmptyHistory() async throws {
        let client = makeClient(
            body: jsonData([
                "status": "1",
                "message": "OK",
                "result": [],
            ])
        )

        let transactions = try await client.getTransactionHistory(
            for: "0xabc",
            chainId: 1
        )

        #expect(transactions.isEmpty)
    }

    @Test("Builds Etherscan-compatible request query")
    func buildsExpectedRequestQuery() async throws {
        let identifier = UUID().uuidString
        let url = URL(string: "https://indexer.example/\(identifier)")!
        StubURLProtocol.register(
            statusCode: 200,
            body: responseBody(
                nonce: "7",
                blockNumber: "123456",
                timestamp: "1720000000"
            ),
            forPath: "/\(identifier)"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        let client = EVMIndexerClient(
            baseURL: url,
            apiKey: "secret-key",
            session: URLSession(configuration: configuration)
        )

        _ = try await client.getTransactionHistory(
            for: "0xabc",
            chainId: 1
        )

        let request = try #require(
            StubURLProtocol.request(forPath: "/\(identifier)")
        )
        let requestURL = try #require(request.url)
        let components = try #require(
            URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        )
        let query = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            }
        )

        #expect(query["module"] == "account")
        #expect(query["action"] == "txlist")
        #expect(query["address"] == "0xabc")
        #expect(query["sort"] == "desc")
        #expect(query["apikey"] == "secret-key")
    }

    private func makeClient(
        statusCode: Int = 200,
        body: Data,
        apiKey: String? = nil
    ) -> EVMIndexerClient {
        let identifier = UUID().uuidString
        let url = URL(string: "https://indexer.example/\(identifier)")!

        StubURLProtocol.register(
            statusCode: statusCode,
            body: body,
            forPath: "/\(identifier)"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return EVMIndexerClient(
            baseURL: url,
            apiKey: apiKey,
            session: URLSession(configuration: configuration)
        )
    }

    private func responseBody(
        nonce: String,
        blockNumber: String,
        timestamp: String
    ) -> Data {
        jsonData([
            "status": "1",
            "message": "OK",
            "result": [[
                "hash": "0xtransaction",
                "from": "0xsender",
                "to": "0xrecipient",
                "value": "123000000000000000",
                "gasPrice": "42000000000",
                "gas": "21000",
                "nonce": nonce,
                "blockNumber": blockNumber,
                "timeStamp": timestamp,
            ]],
        ])
    }

    private func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    }

    private func expectConfigurationError(
        from client: EVMIndexerClient,
        expectedMessagePrefix: String
    ) async {
        do {
            _ = try await client.getTransactionHistory(for: "0xabc", chainId: 1)
            Issue.record("Expected WalletError.chainConfigurationError.")
        } catch let WalletError.chainConfigurationError(message) {
            #expect(message.hasPrefix(expectedMessagePrefix))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    private struct StubResponse {
        let statusCode: Int
        let body: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var responses: [String: StubResponse] = [:]
    nonisolated(unsafe) private static var requests: [String: URLRequest] = [:]

    static func register(
        statusCode: Int,
        body: Data,
        forPath path: String
    ) {
        lock.lock()
        responses[path] = StubResponse(statusCode: statusCode, body: body)
        lock.unlock()
    }

    static func request(forPath path: String) -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requests.removeValue(forKey: path)
    }

    private static func response(forPath path: String) -> StubResponse? {
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
            let stub = Self.response(forPath: url.path),
            let response = HTTPURLResponse(
                url: url,
                statusCode: stub.statusCode,
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

        Self.lock.lock()
        Self.requests[url.path] = request
        Self.lock.unlock()

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
