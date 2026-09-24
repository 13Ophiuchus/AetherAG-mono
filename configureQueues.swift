// Sources/AetherAGMailServer/Config/configureQueues.swift

import Vapor

func configureQueues(_ app: Application) throws {
    // Register the Flow polling scheduler
    app.queues.use(.synchronous, named: "flow-polling") { queue in
        try queue.add(PollFlowTransactionsScheduler(
            repository: app.credentialIssuanceRecordRepository
        ))
    }

    // Remove IssueCredentialJob registration since it's no longer needed
}
