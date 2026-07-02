import Foundation
import os.log

public struct Logger {
    private let osLog: os.Logger
    public init(label: String) {
        self.osLog = os.Logger(subsystem: "com.aether.wallet", category: label)
    }
    public func info(_ message: String)    { osLog.info("\(message, privacy: .public)") }
    public func warning(_ message: String) { osLog.warning("\(message, privacy: .public)") }
    public func error(_ message: String)   { osLog.error("\(message, privacy: .public)") }
    public func debug(_ message: String)   { osLog.debug("\(message, privacy: .private)") }
}
