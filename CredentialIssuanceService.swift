// Sources/AetherAGMailServer/Services/CredentialIssuanceService.swift

import Vapor
import AetherSharedIdentity

struct CredentialIssuanceService {
    let repository: any CredentialIssuanceRecordRepository
    let flowAnchorService: FlowAnchorService
    private let logger = Logger(label: "AetherAGMailServer.CredentialIssuanceService")

    func issueCredential(
        envelope: CredentialEnvelope,
        subjectDID: String,
        on req: Request
    ) async throws -> CredentialResponse {
        // 1. Persist the credential record first
        let issuanceRecord = CredentialIssuanceRecord(
            id: UUID(),
            credentialID: envelope.id,
            subjectDID: subjectDID,
            anchorStatus: .pending,
            flowTransactionID: nil,
            flowBlockID: nil,
            flowError: nil,
            lastObservedStatus: nil,
            sealedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let persistedRecord = try await repository.upsert(record: issuanceRecord)

        // 2. Submit Flow anchoring
        let transactionID: String
        do {
            transactionID = try await flowAnchorService.anchorCredential(
                credentialID: envelope.id,
                subjectDID: subjectDID,
                on: req
            )

            // 3. Update with transaction ID
            let updatedRecord = CredentialIssuanceRecord(
                id: persistedRecord.id,
                credentialID: persistedRecord.credentialID,
                subjectDID: persistedRecord.subjectDID,
                anchorStatus: .pending,
                flowTransactionID: transactionID,
                flowBlockID: nil,
                flowError: nil,
                lastObservedStatus: nil,
                sealedAt: nil,
                createdAt: persistedRecord.createdAt,
                updatedAt: Date()
            )

            try await repository.upsert(record: updatedRecord)
        } catch {
            logger.error("Flow anchoring failed for credential \(envelope.id): \(error.localizedDescription)")
            // Continue with issuance even if anchoring fails
        }

        // 4. Return the credential (same as before)
        return CredentialResponse(
            credential: envelope.jwt,
            credentialID: envelope.id
        )
    }
}
