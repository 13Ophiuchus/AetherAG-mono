import Foundation

public class Logger {
    public let label: String
    
    public init(label: String) {
        self.label = label
    }
    
    public func info(_ message: String) {
        print("[INFO] [\(label)] \(message)")
    }
    
    public func warning(_ message: String) {
        print("[WARNING] [\(label)] \(message)")
    }
    
    public func error(_ message: String) {
        print("[ERROR] [\(label)] \(message)")
    }
    
    public func debug(_ message: String) {
        print("[DEBUG] [\(label)] \(message)")
    }
}