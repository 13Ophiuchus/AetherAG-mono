import Foundation

public protocol SolanaTokenListStorage: Sendable {
    func getTokens() async -> Set<TokenMetadata>?
    func save(tokens: Set<TokenMetadata>?) async
}

public final class InMemorySolanaTokenListStorage: SolanaTokenListStorage, @unchecked Sendable {
    var value: Set<TokenMetadata>? = []

    public init() {}

    public func getTokens() async -> Set<TokenMetadata>? {
        value
    }

    public func save(tokens: Set<TokenMetadata>?) async {
        value = tokens
    }
}
