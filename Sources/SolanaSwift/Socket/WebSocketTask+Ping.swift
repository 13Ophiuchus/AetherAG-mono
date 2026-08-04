import Foundation

extension WebSocketTask {
    func sendPingAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.sendPing { error in
                if let error {
                    continuation.resume(throwing: WebSocketError.connectionFailed(underlying: error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func sendPingWithTimeout(_ timeout: TimeInterval = 10) async throws {
        try await withThrowingTaskGroup(of: Void.self) { [self] group in
            group.addTask { [self] in try await sendPingAsync() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw WebSocketError.pingTimeout
            }
            try await group.next()
            group.cancelAll()
        }
    }
}
