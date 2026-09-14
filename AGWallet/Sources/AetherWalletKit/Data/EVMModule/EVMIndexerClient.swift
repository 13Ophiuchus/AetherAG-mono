//
//  EVMIndexerClient.swift
//  AGWallet
//
//  Fetches EVM transaction history via an Etherscan-compatible indexer API.
//  Mirrors BitcoinEsploraClient's shape (constructor-injected URLSession,
//  path/query-based URL building, JSONDecoder, shared validate() helper)
//  for consistency across chain modules.
//

import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class EVMIndexerClient: @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String?
    private let session: URLSession
    private let logger = Logger(label: "AetherWalletKit.EVMIndexerClient")

    init(
        baseURL: URL,
        apiKey: String? = nil,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Fetches the normal transaction list for an address via an
    /// Etherscan-compatible `module=account&action=txlist` endpoint.
    /// Never logs the API key; only its presence/absence is logged.
    func getTransactionHistory(
        for address: String,
        chainId: Int
    ) async throws -> [UnifiedTransaction] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "module", value: "account"),
            URLQueryItem(name: "action", value: "txlist"),
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "sort", value: "desc"),
        ]
        if let apiKey, !apiKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: apiKey))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw WalletError.chainConfigurationError("Failed to construct indexer URL")
        }

        logger.info("Fetching EVM transaction history for chainId \(chainId) (apiKey present: \(apiKey != nil))")

        let (data, response) = try await session.data(from: url)
        try validate(response, data: data)

        let decoded = try JSONDecoder().decode(EtherscanTxListResponse.self, from: data)

        guard decoded.status == "1" || decoded.result.isEmpty else {
            throw WalletError.chainConfigurationError("Indexer error: \(decoded.message)")
        }

        return decoded.result.map { tx in
            .evm(
                EVMTransaction(
                    hash: tx.hash,
                    from: tx.from,
                    to: tx.to,
                    value: tx.value,
                    gasPrice: tx.gasPrice,
                    gasLimit: tx.gas,
                    nonce: Int(tx.nonce) ?? 0,
                    chainId: chainId,
                    blockNumber: Int(tx.blockNumber),
                    timestamp: Date(timeIntervalSince1970: TimeInterval(Int(tx.timeStamp) ?? 0))
                )
            )
        }
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletError.chainConfigurationError("Invalid indexer response")
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WalletError.chainConfigurationError(
                "Indexer request failed (\(httpResponse.statusCode)): \(responseBody)"
            )
        }
    }
}

/// Decode target matching the Etherscan-compatible `txlist` action's JSON shape.
private struct EtherscanTxListResponse: Decodable {
    let status: String
    let message: String
    let result: [EtherscanTx]
}

private struct EtherscanTx: Decodable {
    let hash: String
    let from: String
    let to: String
    let value: String
    let gasPrice: String
    let gas: String
    let nonce: String
    let blockNumber: String
    let timeStamp: String
}
