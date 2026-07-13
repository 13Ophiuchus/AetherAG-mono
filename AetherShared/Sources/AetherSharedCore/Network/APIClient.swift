//
//  APIClient.swift
//  AetherSharedCore
//
//  Created by Nicholas Reich on 4/18/26.
//

import Foundation

public enum HTTPMethod: String, Sendable {
  case GET
  case POST
  case PUT
  case PATCH
  case DELETE
}

public enum APIClientError: LocalizedError, Sendable {
  case invalidURL(String)
  case invalidResponse
  case requestFailed(Int, String)
  case encodingFailed(String)
  case decodingFailed(String)

  public var errorDescription: String? {
    switch self {
    case .invalidURL(let url):
      return "Invalid URL: \(url)"
    case .invalidResponse:
      return "Invalid server response."
    case .requestFailed(let statusCode, let body):
      return "Request failed with status \(statusCode): \(body)"
    case .encodingFailed(let message):
      return "Failed to encode request body: \(message)"
    case .decodingFailed(let message):
      return "Failed to decode response: \(message)"
    }
  }
}

public struct EmptyRequestBody: Encodable, Sendable {
  public init() {}
}

public final class APIClient: @unchecked Sendable {
  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let baseURL: URL?

  public init(
    baseURL: URL? = nil,
    session: URLSession = .shared,
    encoder: JSONEncoder = JSONEncoder(),
    decoder: JSONDecoder = JSONDecoder()
  ) {
    self.baseURL = baseURL
    self.session = session
    self.encoder = encoder
    self.decoder = decoder
  }

  // Convenience GET with no body
  public func request<Response: Decodable>(
    _ pathOrURLString: String,
    method: HTTPMethod = .GET
  ) async throws -> Response {
    try await request(pathOrURLString, method: method, body: Optional<EmptyRequestBody>.none)
  }

  public func request<Response: Decodable, RequestBody: Encodable>(
    _ pathOrURLString: String,
    method: HTTPMethod = .POST,
    body: RequestBody?
  ) async throws -> Response {
    let url: URL

    if let baseURL {
      guard let resolved = URL(string: pathOrURLString, relativeTo: baseURL) else {
        throw APIClientError.invalidURL(pathOrURLString)
      }
      url = resolved
    } else {
      guard let resolved = URL(string: pathOrURLString) else {
        throw APIClientError.invalidURL(pathOrURLString)
      }
      url = resolved
    }

    var request = URLRequest(url: url)
    request.httpMethod = method.rawValue
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      do {
        request.httpBody = try encoder.encode(body)
      } catch {
        throw APIClientError.encodingFailed(error.localizedDescription)
      }
    }

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw APIClientError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      let bodyString = String(data: data, encoding: .utf8) ?? ""
      throw APIClientError.requestFailed(httpResponse.statusCode, bodyString)
    }

    do {
      return try decoder.decode(Response.self, from: data)
    } catch {
      throw APIClientError.decodingFailed(error.localizedDescription)
    }
  }
}
