import Foundation

public struct PresentationSubmission: Codable, Sendable, Equatable {
    public let id: String
    public let definitionId: String
    public let descriptorMap: [InputDescriptorMapping]

    enum CodingKeys: String, CodingKey {
        case id
        case definitionId = "definition_id"
        case descriptorMap = "descriptor_map"
    }
}

public final class InputDescriptorMapping: Codable, Sendable, Equatable {
    public let id: String
    public let format: String
    public let path: String
    public let pathNested: InputDescriptorMapping? // For nested claims

    public init(id: String, format: String, path: String, pathNested: InputDescriptorMapping? = nil) {
        self.id = id
        self.format = format
        self.path = path
        self.pathNested = pathNested
    }

    enum CodingKeys: String, CodingKey {
        case id
        case format
        case path
        case pathNested = "path_nested"
    }

    public static func == (lhs: InputDescriptorMapping, rhs: InputDescriptorMapping) -> Bool {
        lhs.id == rhs.id
            && lhs.format == rhs.format
            && lhs.path == rhs.path
            && lhs.pathNested == rhs.pathNested
    }
}
