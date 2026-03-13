import Foundation
import os.log

private let logger = Logger(subsystem: "dev.nekode.Nekode", category: "PluginManager")

@MainActor
class PluginManager: ObservableObject {
    @Published var ccInstalled: Bool = false
    @Published var ocInstalled: Bool = false
    @Published var ocConfigExists: Bool = false
    @Published var copilotInstalled: Bool = false
    @Published var vscodeExists: Bool = false

    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let ocPluginPath = home.appendingPathComponent(".config/opencode/plugins/nekode.js")
    private static let copilotHooksDir = home.appendingPathComponent(".nekode/plugins/copilot/hooks")
    private static let copilotRunHook = copilotHooksDir.appendingPathComponent("run-hook.sh")
    private static let copilotHooksJSON = copilotHooksDir.appendingPathComponent("hooks.json")
    private static let vscodeSettingsPath = home.appendingPathComponent(
        "Library/Application Support/Code/User/settings.json"
    )

    init() {
        refresh()
    }

    func refresh() {
        let fm = FileManager.default
        let home = Self.home

        let ccDir = home.appendingPathComponent(".claude/plugins/cache/nekode")
        var isDir: ObjCBool = false
        ccInstalled = fm.fileExists(atPath: ccDir.path, isDirectory: &isDir) && isDir.boolValue

        let ocConfigDir = home.appendingPathComponent(".config/opencode")
        ocConfigExists = fm.fileExists(atPath: ocConfigDir.path)

        ocInstalled = fm.fileExists(atPath: Self.ocPluginPath.path)

        let vscodeDir = Self.vscodeSettingsPath.deletingLastPathComponent()
        vscodeExists = fm.fileExists(atPath: vscodeDir.path)

        copilotInstalled = fm.fileExists(atPath: Self.copilotRunHook.path)
            && copilotHooksInVSCodeSettings()
    }

    // MARK: - opencode

    func installOpenCodePlugin() -> Bool {
        defer { refresh() }

        guard let bundledPlugin = Bundle.main.url(forResource: "opencode-plugin", withExtension: "js"),
              let bundledData = try? Data(contentsOf: bundledPlugin) else {
            logger.error("Could not read bundled opencode plugin")
            return false
        }

        let pluginsDir = Self.ocPluginPath.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
            try bundledData.write(to: Self.ocPluginPath, options: .atomic)
            logger.info("Installed opencode plugin to \(Self.ocPluginPath.path, privacy: .public)")
            return true
        } catch {
            logger.error("Failed to install opencode plugin: \(error, privacy: .public)")
            return false
        }
    }

    func removeOpenCodePlugin() -> Bool {
        defer { refresh() }

        do {
            try FileManager.default.removeItem(at: Self.ocPluginPath)
            logger.info("Removed opencode plugin from \(Self.ocPluginPath.path, privacy: .public)")
            return true
        } catch {
            logger.error("Failed to remove opencode plugin: \(error, privacy: .public)")
            return false
        }
    }

    // MARK: - VS Code Copilot

    func installCopilotHooks() -> Bool {
        defer { refresh() }

        do {
            // 1. Copy hook files to ~/.nekode/plugins/copilot/hooks/
            try installCopilotHookFiles()

            // 2. Inject hooks config into VS Code settings.json
            try injectCopilotHooksIntoVSCodeSettings()

            logger.info("Installed VS Code Copilot hooks")
            return true
        } catch {
            logger.error("Failed to install Copilot hooks: \(error, privacy: .public)")
            return false
        }
    }

    func removeCopilotHooks() -> Bool {
        defer { refresh() }

        do {
            // 1. Remove hooks from VS Code settings.json
            try removeCopilotHooksFromVSCodeSettings()

            // 2. Remove hook files
            let pluginDir = Self.copilotHooksDir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: pluginDir.path) {
                try FileManager.default.removeItem(at: pluginDir)
            }

            logger.info("Removed VS Code Copilot hooks")
            return true
        } catch {
            logger.error("Failed to remove Copilot hooks: \(error, privacy: .public)")
            return false
        }
    }

    // MARK: - Copilot Helpers

    private func installCopilotHookFiles() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.copilotHooksDir, withIntermediateDirectories: true)

        guard let bundledHooksJSON = Bundle.main.url(forResource: "copilot-hooks", withExtension: "json"),
              let bundledRunHook = Bundle.main.url(forResource: "copilot-run-hook", withExtension: "sh") else {
            throw PluginError.bundledResourceMissing
        }

        let hooksData = try Data(contentsOf: bundledHooksJSON)
        try hooksData.write(to: Self.copilotHooksJSON, options: .atomic)

        let runHookData = try Data(contentsOf: bundledRunHook)
        try runHookData.write(to: Self.copilotRunHook, options: .atomic)

        // Make run-hook.sh executable (0o755)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.copilotRunHook.path)
    }

    /// The key VS Code uses to locate hook configuration files.
    private static let hookFilesLocationsKey = "chat.hookFilesLocations"
    /// The path we register in chat.hookFilesLocations (tilde form, as VS Code expects).
    private static let copilotHooksLocationValue = "~/.nekode/plugins/copilot/hooks"

    private func injectCopilotHooksIntoVSCodeSettings() throws {
        let settingsURL = Self.vscodeSettingsPath
        var settings = try loadJSONObject(from: settingsURL)

        // Add our hooks directory to chat.hookFilesLocations
        var locations = settings[Self.hookFilesLocationsKey] as? [String: Any] ?? [:]
        locations[Self.copilotHooksLocationValue] = true
        settings[Self.hookFilesLocationsKey] = locations

        // Clean up legacy key from earlier install attempts
        settings.removeValue(forKey: "github.copilot.chat.agent.hooks")

        try writeJSONObject(settings, to: settingsURL)
    }

    private func removeCopilotHooksFromVSCodeSettings() throws {
        let settingsURL = Self.vscodeSettingsPath
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }

        var settings = try loadJSONObject(from: settingsURL)

        // Remove our entry from chat.hookFilesLocations
        if var locations = settings[Self.hookFilesLocationsKey] as? [String: Any] {
            locations.removeValue(forKey: Self.copilotHooksLocationValue)
            if locations.isEmpty {
                settings.removeValue(forKey: Self.hookFilesLocationsKey)
            } else {
                settings[Self.hookFilesLocationsKey] = locations
            }
        }

        // Also clean up legacy key
        settings.removeValue(forKey: "github.copilot.chat.agent.hooks")

        try writeJSONObject(settings, to: settingsURL)
    }

    private func copilotHooksInVSCodeSettings() -> Bool {
        guard let settings = try? loadJSONObject(from: Self.vscodeSettingsPath),
              let locations = settings[Self.hookFilesLocationsKey] as? [String: Any],
              let enabled = locations[Self.copilotHooksLocationValue] as? Bool,
              enabled else {
            return false
        }
        return true
    }

    // MARK: - JSON Helpers

    private func loadJSONObject(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        // Strip comments and trailing commas for JSONC (VS Code settings format)
        let cleaned = Self.stripJSONC(data)
        guard let obj = try JSONSerialization.jsonObject(with: cleaned) as? [String: Any] else {
            throw PluginError.invalidJSON
        }
        return obj
    }

    private func writeJSONObject(_ obj: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    /// Strip single-line comments (//) and trailing commas from JSONC content.
    /// VS Code settings.json often uses JSONC format.
    static func stripJSONC(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8) else { return data }
        var result = ""
        var inString = false
        var escaped = false
        var i = text.startIndex

        while i < text.endIndex {
            let ch = text[i]

            if escaped {
                result.append(ch)
                escaped = false
                i = text.index(after: i)
                continue
            }

            if ch == "\\" && inString {
                result.append(ch)
                escaped = true
                i = text.index(after: i)
                continue
            }

            if ch == "\"" {
                inString.toggle()
                result.append(ch)
                i = text.index(after: i)
                continue
            }

            if !inString {
                let next = text.index(after: i)
                // Single-line comment
                if ch == "/" && next < text.endIndex && text[next] == "/" {
                    // Skip to end of line
                    if let eol = text[i...].firstIndex(of: "\n") {
                        i = eol
                    } else {
                        break
                    }
                    continue
                }
                // Block comment
                if ch == "/" && next < text.endIndex && text[next] == "*" {
                    let searchStart = text.index(next, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
                    if searchStart < text.endIndex,
                       let endComment = text.range(of: "*/", range: searchStart..<text.endIndex) {
                        i = endComment.upperBound
                    } else {
                        break
                    }
                    continue
                }
            }

            result.append(ch)
            i = text.index(after: i)
        }

        // Remove trailing commas before } or ]
        let trailingComma = try! NSRegularExpression(pattern: #",\s*([\]\}])"#)
        let mutable = NSMutableString(string: result)
        trailingComma.replaceMatches(in: mutable, range: NSRange(location: 0, length: mutable.length), withTemplate: "$1")

        return (mutable as String).data(using: .utf8) ?? data
    }

    private enum PluginError: LocalizedError {
        case bundledResourceMissing
        case invalidJSON

        var errorDescription: String? {
            switch self {
            case .bundledResourceMissing: return "Bundled plugin resource not found"
            case .invalidJSON: return "Invalid JSON"
            }
        }
    }
}
