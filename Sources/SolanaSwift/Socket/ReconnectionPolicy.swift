import Foundation

actor ReconnectionPolicy {
    private var attempt = 0
    private let maxAttempts: Int
    private let base: TimeInterval

    init(maxAttempts: Int = 5, base: TimeInterval = 1.0) {
        self.maxAttempts = maxAttempts
        self.base = base
    }

    func nextDelay() throws -> TimeInterval {
        guard attempt < maxAttempts else { throw WebSocketError.cancelled }
        let delay = base * pow(2.0, Double(attempt))
        attempt += 1
        return min(delay, 30.0)
    }

    func reset() { attempt = 0 }
}
