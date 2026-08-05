import Foundation
import AetherSharedIdentity

public protocol DIDDocumentMaking: Sendable {
    func makeDIDDocument(
        did: String,
        keyFragment: String,
        jwk: [String: String],
        inboxURL: String?
    ) -> DIDDocument
}
