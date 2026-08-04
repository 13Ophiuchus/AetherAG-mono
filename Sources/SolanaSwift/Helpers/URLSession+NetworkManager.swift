import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Available on all platforms — the #if above only gates the import, not the extension.
extension URLSession: NetworkManager {
    public func requestData(request: URLRequest) async throws -> Data {
        let (data, _) = try await self.data(for: request)
        return data
    }
}
