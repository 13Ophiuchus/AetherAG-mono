// Sources/AetherAGMailServer/Models/CredentialAnchorStatus.swift

import Foundation

enum CredentialAnchorStatus: String, Codable, Sendable {
    case pending
    case anchored
    case anchorFailed

    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "pending": self = .pending
        case "anchored": self = .anchored
        case "anchorfailed", "anchor_failed":
            self = .anchorFailed
        default:
            return nil
        }
    }
}
