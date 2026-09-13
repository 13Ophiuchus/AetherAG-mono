//
//  DynamicCodingKeys.swift
//  AetherAGMailShared
//
//  Created by Nicholas Reich on 4/19/26.
//

import Foundation

public struct DynamicCodingKeys: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    public init?(stringValue: String) {
        self.init(stringValue)
    }

    public init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
