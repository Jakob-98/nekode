import Foundation

struct HookInput: Decodable {
    let sessionId: String
    let cwd: String
    var transcriptPath: String?
    var permissionMode: String?
    let hookEventName: String
    var prompt: String?
    var toolName: String?
    var toolInput: [String: String]?
    var notificationType: String?
    var message: String?
    var title: String?
    var trigger: String?

    // Flexible CodingKey that matches any string — used to support both
    // snake_case (Claude Code) and camelCase (VS Code Copilot) JSON keys.
    private struct FlexKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
    }

    /// Try to decode a value using the first matching key from a list of alternatives.
    private static func decodeFirst<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<FlexKey>,
        keys: [String]
    ) throws -> T {
        for key in keys {
            if let flexKey = FlexKey(stringValue: key),
               let value = try? container.decode(T.self, forKey: flexKey) {
                return value
            }
        }
        // Fall through: throw a proper error using the first key
        let flexKey = FlexKey(stringValue: keys[0])!
        return try container.decode(T.self, forKey: flexKey)
    }

    /// Try to optionally decode a value using the first matching key from a list of alternatives.
    private static func decodeFirstIfPresent<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<FlexKey>,
        keys: [String]
    ) -> T? {
        for key in keys {
            if let flexKey = FlexKey(stringValue: key),
               let value = try? container.decode(T.self, forKey: flexKey) {
                return value
            }
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FlexKey.self)

        // Required fields — try camelCase first, then snake_case
        sessionId = try Self.decodeFirst(String.self, from: container, keys: ["sessionId", "session_id"])
        cwd = try Self.decodeFirst(String.self, from: container, keys: ["cwd"])
        hookEventName = try Self.decodeFirst(String.self, from: container, keys: ["hookEventName", "hook_event_name"])

        // Optional fields — try camelCase first, then snake_case
        transcriptPath = Self.decodeFirstIfPresent(String.self, from: container, keys: ["transcriptPath", "transcript_path"])
        permissionMode = Self.decodeFirstIfPresent(String.self, from: container, keys: ["permissionMode", "permission_mode"])
        prompt = Self.decodeFirstIfPresent(String.self, from: container, keys: ["prompt"])
        toolName = Self.decodeFirstIfPresent(String.self, from: container, keys: ["toolName", "tool_name"])
        notificationType = Self.decodeFirstIfPresent(String.self, from: container, keys: ["notificationType", "notification_type"])
        message = Self.decodeFirstIfPresent(String.self, from: container, keys: ["message"])
        title = Self.decodeFirstIfPresent(String.self, from: container, keys: ["title"])
        trigger = Self.decodeFirstIfPresent(String.self, from: container, keys: ["trigger"])

        // toolInput needs special handling for mixed-type values
        let toolInputKeys = ["toolInput", "tool_input"]
        toolInput = nil
        for key in toolInputKeys {
            if let flexKey = FlexKey(stringValue: key),
               let rawDict = try? container.decode([String: ToolInputValue].self, forKey: flexKey) {
                toolInput = rawDict.compactMapValues { $0.stringValue }
                break
            }
        }
    }
}

private enum ToolInputValue: Decodable {
    case string(String)
    case other

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .other
        }
    }
}
