import Foundation

public enum WebSocketError: Error, Sendable {
    case connectionFailed(underlying: Error)
    case messageSendFailed(underlying: Error)
    case receiveDecodingFailed(underlying: Error)
    case pingTimeout
    case serverClosed(code: Int, reason: String)
    case cancelled
}
