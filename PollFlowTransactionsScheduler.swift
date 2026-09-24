// Sources/AetherAGMailServer/Jobs/PollFlowTransactionsScheduler.swift

import Vapor
import AetherSharedIdentity

struct PollFlowTransactionsScheduler: AsyncScheduledJob {
    let repository: any CredentialIssuanceRecordRepository
    private let logger = Logger(label: "AetherAGMailServer.PollFlowTransactionsScheduler")

    func run(context: QueueContext) async throws {
        let pendingRecords = try await repository.findPending()

        for record in pendingRecords {
            guard let transactionID = record.flowTransactionID else {
                logger.warning("Pending record \(record.id) has no transaction ID")
                continue
            }

            let payload = PollFlowTransactionStatusJob.Payload(
                transactionID: transactionID,
                credentialID: record.credentialID,
                subjectDID: record.subjectDID,
                attempt: 0
            )

            try await context.queue.dispatch(
                PollFlowTransactionStatusJob.self,
                .init(payload)
            )
        }
    }
}
