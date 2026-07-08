import Foundation

struct ToolInvocation: Codable, Equatable, Hashable {
    var toolID: String
    var displayName: String
    var configuration: ToolConfigurationPayload
    var version: Int

    init(
        toolID: String,
        displayName: String,
        configuration: ToolConfigurationPayload = .empty,
        version: Int = 1
    ) {
        self.toolID = toolID
        self.displayName = displayName
        self.configuration = configuration
        self.version = version
    }
}

struct ToolConfigurationPayload: Codable, Equatable, Hashable {
    var values: [String: ToolConfigurationValue]

    init(values: [String: ToolConfigurationValue] = [:]) {
        self.values = values
    }

    static let empty = ToolConfigurationPayload()
}

enum ToolConfigurationValue: Codable, Equatable, Hashable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)

    private enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    private enum ValueType: String, Codable {
        case string
        case bool
        case int
        case double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)

        switch type {
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .int:
            self = .int(try container.decode(Int.self, forKey: .value))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .value))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .string(let value):
            try container.encode(ValueType.string, forKey: .type)
            try container.encode(value, forKey: .value)
        case .bool(let value):
            try container.encode(ValueType.bool, forKey: .type)
            try container.encode(value, forKey: .value)
        case .int(let value):
            try container.encode(ValueType.int, forKey: .type)
            try container.encode(value, forKey: .value)
        case .double(let value):
            try container.encode(ValueType.double, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }
}

