import Foundation
#if canImport(os.log)
import os.log
#endif

public struct Logger {
#if canImport(os.log)
    private let osLog: os.Logger

    public init(label: String) {
        self.osLog = os.Logger(subsystem: "com.aether.wallet", category: label)
    }

    public func info(_ message: String)    { osLog.info("\(message, privacy: .public)") }
    public func warning(_ message: String) { osLog.warning("\(message, privacy: .public)") }
    public func error(_ message: String)   { osLog.error("\(message, privacy: .public)") }
    public func debug(_ message: String)   { osLog.debug("\(message, privacy: .private)") }
#else
    private let label: String

    public init(label: String) {
        self.label = label
    }

    public func info(_ message: String)    { print("[INFO] [\(label)] \(message)") }
    public func warning(_ message: String) { print("[WARNING] [\(label)] \(message)") }
    public func error(_ message: String)   { print("[ERROR] [\(label)] \(message)") }
    public func debug(_ message: String)   { print("[DEBUG] [\(label)] \(message)") }
#endif
}
