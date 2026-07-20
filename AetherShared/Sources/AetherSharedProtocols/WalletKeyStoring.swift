import Foundation

public protocol WalletKeyStoring: Sendable {
    func storeKey(
        _ key: Data,
        for identifier: String,
        requiresBiometrics: Bool
    ) async throws

    func retrieveKey(for identifier: String) async throws -> Data?

    func deleteKey(for identifier: String) async throws
}
