import AetherSharedIdentity
import Foundation

public protocol DIDDocumentMaking: Sendable {
    func makeDIDDocument(
        did: String,
        keyFragment: String,
        jwk: [String: String],
        inboxURL: String?
    ) -> DIDDocument
}
