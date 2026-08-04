import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol NetworkManager: Sendable {
    func requestData(request: URLRequest) async throws -> Data
}
