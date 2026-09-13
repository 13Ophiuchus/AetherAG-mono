import AetherSharedIdentity
import Foundation

public protocol DIDDocumentServiceProtocol: Sendable {
    func makeDIDDocument(
        did: String,
        keyFragment: String,
        jwk: [String: String],
        inboxURL: String?
    ) -> DIDDocument
}
