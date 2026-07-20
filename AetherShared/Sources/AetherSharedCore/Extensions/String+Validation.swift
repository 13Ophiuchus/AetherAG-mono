//
//  String+Validation.swift
//  AetherAG
//
//  Created by Nicholas Reich on 4/22/26.
//
import Foundation

extension String {
  public var isValidEmail: Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: self)
  }

  public var isValidDID: Bool {
    let didRegex = "^did:[a-z0-9]+:[a-zA-Z0-9._:-]+$"
    return NSPredicate(format: "SELF MATCHES %@", didRegex).evaluate(with: self)
  }
}
