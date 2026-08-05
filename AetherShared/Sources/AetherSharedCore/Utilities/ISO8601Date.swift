import Foundation

public enum ISO8601Date {
  @MainActor public static let formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  @MainActor public static func string(from date: Date) -> String {
    formatter.string(from: date)
  }
}
