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

protocol EVMIndexerHTTPClient: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: EVMIndexerHTTPClient {}

final class EVMIndexerClient: @unchecked Sendable {
    private let baseURL: URL
    private let apiKey: String?
    private let session: any EVMIndexerHTTPClient
    private let logger = Logger(label: "AetherWalletKit.EVMIndexerClient")

    init(
        baseURL: URL,
        apiKey: String? = nil,
        session: any EVMIndexerHTTPClient = URLSession.shared
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

        return try decoded.result.map { tx in
            let value = try Self.validatedDecimalString(
                tx.value,
                field: "value",
                transactionHash: tx.hash
            )
            let gasPrice = try Self.validatedDecimalString(
                tx.gasPrice,
                field: "gasPrice",
                transactionHash: tx.hash
            )
            let gasLimit = try Self.validatedDecimalString(
                tx.gas,
                field: "gas",
                transactionHash: tx.hash
            )
            let nonce = try Self.validatedInt(
                tx.nonce,
                field: "nonce",
                transactionHash: tx.hash
            )
            let blockNumber = try Self.validatedOptionalInt(
                tx.blockNumber,
                field: "blockNumber",
                transactionHash: tx.hash
            )
            let timestamp = try Self.validatedTimestamp(
                tx.timeStamp,
                transactionHash: tx.hash
            )

            return .evm(
                EVMTransaction(
                    hash: tx.hash,
                    from: tx.from,
                    to: tx.to,
                    value: value,
                    gasPrice: gasPrice,
                    gasLimit: gasLimit,
                    nonce: nonce,
                    chainId: chainId,
                    blockNumber: blockNumber,
                    timestamp: timestamp
                )
            )
        }
    }

    private static func validatedDecimalString(
        _ value: String,
        field: String,
        transactionHash: String
    ) throws -> String {
        guard !value.isEmpty,
              value.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 })
        else {
            throw WalletError.invalidResponse(
                "Invalid EVM \(field) in indexer response for transaction \(transactionHash)"
            )
        }

        return value
    }

    private static func validatedInt(
        _ value: String,
        field: String,
        transactionHash: String
    ) throws -> Int {
        let decimalValue = try validatedDecimalString(
            value,
            field: field,
            transactionHash: transactionHash
        )

        guard let parsed = Int(decimalValue) else {
            throw WalletError.invalidResponse(
                "EVM \(field) is outside supported range for transaction \(transactionHash)"
            )
        }

        return parsed
    }

    private static func validatedOptionalInt(
        _ value: String,
        field: String,
        transactionHash: String
    ) throws -> Int? {
        guard !value.isEmpty else {
            return nil
        }

        return try validatedInt(
            value,
            field: field,
            transactionHash: transactionHash
        )
    }

    private static func validatedTimestamp(
        _ value: String,
        transactionHash: String
    ) throws -> Date {
        let decimalValue = try validatedDecimalString(
            value,
            field: "timeStamp",
            transactionHash: transactionHash
        )

        guard let seconds = Int64(decimalValue) else {
            throw WalletError.invalidResponse(
                "EVM timeStamp is outside supported range for transaction \(transactionHash)"
            )
        }

        return Date(timeIntervalSince1970: TimeInterval(seconds))
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
