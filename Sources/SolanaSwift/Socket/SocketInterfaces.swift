import Foundation

// MARK: - WebSocketMessage

public enum WebSocketMessage {
    case string(String)
    case data(Data)
}

// MARK: - WebSocketTask

public protocol WebSocketTask: AnyObject {
    func send(_ message: WebSocketMessage) async throws
    func receive() async throws -> WebSocketMessage
    func sendPing(pongReceiveHandler: @escaping @Sendable (Error?) -> Void)
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func resume()
}

// MARK: - URLSessionWebSocketTask conformance
// No @retroactive — WebSocketTask is declared in this module

extension URLSessionWebSocketTask: WebSocketTask {
    public func send(_ message: WebSocketMessage) async throws {
        switch message {
        case .string(let text):
            try await send(URLSessionWebSocketTask.Message.string(text))
        case .data(let data):
            try await send(URLSessionWebSocketTask.Message.data(data))
        }
    }

    public func receive() async throws -> WebSocketMessage {
        let nativeTask: URLSessionWebSocketTask = self
        let raw = try await nativeTask.receive() as URLSessionWebSocketTask.Message
        switch raw {
        case .string(let text): return .string(text)
        case .data(let data):   return .data(data)
        @unknown default:
            throw WebSocketError.receiveDecodingFailed(
                underlying: NSError(domain: "WebSocket", code: -1)
            )
        }
    }
}

// MARK: - WebSocketTaskProvider (testability)

public protocol WebSocketTaskProvider {
    func makeTask(with url: URL) -> WebSocketTask
}

public struct URLSessionTaskProvider: WebSocketTaskProvider {
    public init() {}
    public func makeTask(with url: URL) -> WebSocketTask {
        URLSession(configuration: .default).webSocketTask(with: url)
    }
}

// MARK: - SolanaSocketEventsDelegate
// Matches Socket.swift call-sites and git HEAD exactly

public protocol SolanaSocketEventsDelegate: AnyObject {
    func connected()
    func nativeAccountNotification(notification: SocketNativeAccountNotification)
    func tokenAccountNotification(notification: SocketTokenAccountNotification)
    func programNotification(notification: SocketProgramAccountNotification)
    func signatureNotification(notification: SocketSignatureNotification)
    func logsNotification(notification: SocketLogsNotification)
    func unsubscribed(id: String)
    func subscribed(socketId: UInt64, id: String)
    func disconnected(reason: String, code: Int)
    func error(error: Error?)
}

public extension SolanaSocketEventsDelegate {
    func connected() {}
    func nativeAccountNotification(notification _: SocketNativeAccountNotification) {}
    func tokenAccountNotification(notification _: SocketTokenAccountNotification) {}
    func programNotification(notification _: SocketProgramAccountNotification) {}
    func signatureNotification(notification _: SocketSignatureNotification) {}
    func logsNotification(notification _: SocketLogsNotification) {}
    func unsubscribed(id _: String) {}
    func subscribed(socketId _: UInt64, id _: String) {}
    func disconnected(reason _: String, code _: Int) {}
    func error(error _: Error?) {}
}
