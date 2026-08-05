//
//  DateProviding.swift
//  AetherAG
//
//  Created by Nicholas Reich on 4/30/26.
//

import Foundation

public protocol DateProviding: Sendable {
  func now() -> Date
}

public struct SystemDateProvider: DateProviding {
  public init() {}
  public func now() -> Date { Date() }
}
