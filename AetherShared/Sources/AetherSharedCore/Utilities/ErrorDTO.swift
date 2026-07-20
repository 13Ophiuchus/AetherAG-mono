import Foundation

public struct ErrorDTO: Codable, Equatable, Hashable, Sendable {
  public let error: String
  public let errorDescription: String

  public init(
    error: String,
    errorDescription: String
  ) {
    self.error = error
    self.errorDescription = errorDescription
  }

  public enum CodingKeys: String, CodingKey {
    case error
    case errorDescription = "error_description"
  }
}
