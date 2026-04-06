import Foundation
import os.log

private let logger = Logger(subsystem: "dev.nekode.Nekode", category: "PluginManager")

@MainActor
class PluginManager: ObservableObject {
    @Published var ccInstalled: Bool = false
    @Published var ccExists: Bool = false
    @Published var ocInstalled: Bool = false
    @Published var ocConfigExists: Bool = false
    @Published var copilotInstalled: Bool = false
    @Published var vscodeExists: Bool = false
    @Published var copilotCLIInstalled: Bool = false
    @Published var copilotCLIExists: Bool = false

    private static let home = FileManager.default.homeDirectoryForCurrentUser
    private static let ccHooksDir = home.appendingPathComponent(".nekode/plugins/claude/hooks")
    private static let ccRunHook = ccHooksDir.appendingPathComponent("run-hook.sh")
    private static let ccSettingsPath = home.appendingPathComponent(".claude/settings.json")
    private static let ocPluginPath = home.appendingPathComponent(".config/opencode/plugins/nekode.js")
    private static let copilotHooksDir = home.appendingPathComponent(".nekode/plugins/copilot/hooks")
    private static let copilotRunHook = copilotHooksDir.appendingPathComponent("run-hook.sh")
    private static let copilotHooksJSON = copilotHooksDir.appendingPathComponent("hooks.json")
    private static let vscodeSettingsPath = home.appendingPathComponent(
        "Library/Application Support/Code/User/settings.json"
    )
    private static let copilotCLIHooksDir = home.appendingPathComponent(".nekode/plugins/copilot-cli/hooks")
    private static let copilotCLIRunHook = copilotCLIHooksDir.appendingPathComponent("run-hook.sh")
    private static let copilotCLIHooksJSON = copilotCLIHooksDir.appendingPathComponent("hooks.json")
    /// Copilot CLI loads personal hooks from ~/.copilot/hooks/
    private static let copilotCLIUserHooksDir = home.appendingPathComponent(".copilot/hooks")

    init() {
        refresh()
    }

    func refresh() {
        let fm = FileManager.default
        let home = Self.home

        // Claude Code exists if ~/.claude/ directory is present (created on first run)
        let claudeDir = home.appendingPathComponent(".claude")
        ccExists = fm.fileExists(atPath: claudeDir.path)

        // Claude Code installed = our run-hook.sh exists AND settings.json has our hooks
        ccInstalled = fm.fileExists(atPath: Self.ccRunHook.path)
            && ccHooksInClaudeSettings()

        let ocConfigDir = home.appendingPathComponent(".config/opencode")
        ocConfigExists = fm.fileExists(atPath: ocConfigDir.path)

        ocInstalled = fm.fileExists(atPath: Self.ocPluginPath.path)

        let vscodeDir = Self.vscodeSettingsPath.deletingLastPathComponent()
        vscodeExists = fm.fileExists(atPath: vscodeDir.path)

        copilotInstalled = fm.fileExists(atPath: Self.copilotRunHook.path)
            && copilotHooksInVSCodeSettings()

        // Copilot CLI: detect if `copilot` binary exists (check common locations)
        copilotCLIExists = fm.fileExists(atPath: "/usr/local/bin/copilot")
            || fm.fileExists(atPath: home.appendingPathComponent(".local/bin/copilot").path)
            || fm.fileExists(atPath: "/opt/homebrew/bin/copilot")

        // Copilot CLI hooks installed = our hooks.json symlinked/present in ~/.copilot/hooks/
        let nekodeHooksJSON = Self.copilotCLIUserHooksDir.appendingPathComponent("nekode-hooks.json")
        copilotCLIInstalled = fm.fileExists(atPath: nekodeHooksJSON.path)
    }

    // MARK: - Claude Code

    /// The run-hook.sh command prefix injected into ~/.claude/settings.json hooks.
    /// Points to our managed copy at ~/.nekode/plugins/claude/hooks/run-hook.sh.
    private static let ccRunHookCommand = "~/.nekode/plugins/claude/hooks/run-hook.sh"

    /// All Claude Code lifecycle events we hook into.
    private static let ccHookEvents: [(event: String, matcher: String)] = [
        ("SessionStart", "startup|resume"),
        ("UserPromptSubmit", ".*"),
        ("PreToolUse", ".*"),
        ("PostToolUse", ".*"),
        ("Stop", ".*"),
        ("Notification", ".*"),
        ("PermissionRequest", ".*"),
        ("PreCompact", ".*"),
    ]

    func installClaudeCodePlugin() -> Bool {
        defer { refresh() }

        do {
            // Clean up old plugin-cache approach (pre-v1.0.4)
            let legacyCacheDir = Self.home.appendingPathComponent(".claude/plugins/cache/nekode")
            if FileManager.default.fileExists(atPath: legacyCacheDir.path) {
                try? FileManager.default.removeItem(at: legacyCacheDir)
                logger.info("Removed legacy Claude Code plugin cache")
            }

            // 1. Copy run-hook.sh to ~/.nekode/plugins/claude/hooks/
            try installCCHookFiles()

            // 2. Inject hooks config into ~/.claude/settings.json
            try injectCCHooksIntoClaudeSettings()

            logger.info("Installed Claude Code hooks into ~/.claude/settings.json")
            return true
        } catch {
            logger.error("Failed to install Claude Code hooks: \(error, privacy: .public)")
            return false
        }
    }

    func removeClaudeCodePlugin() -> Bool {
        defer { refresh() }

        do {
            // 1. Remove hooks from ~/.claude/settings.json
            try removeCCHooksFromClaudeSettings()

            // 2. Remove hook files
            let pluginDir = Self.ccHooksDir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: pluginDir.path) {
                try FileManager.default.removeItem(at: pluginDir)
            }

            logger.info("Removed Claude Code hooks")
            return true
        } catch {
            logger.error("Failed to remove Claude Code hooks: \(error, privacy: .public)")
            return false
        }
    }

    private func installCCHookFiles() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: Self.ccHooksDir, withIntermediateDirectories: true)

        guard let bundledRunHook = Bundle.main.url(forResource: "cc-run-hook", withExtension: "sh") else {
            throw PluginError.bundledResourceMissing
        }

        let runHookData = try Data(contentsOf: bundledRunHook)
        try runHookData.write(to: Self.ccRunHook, options: .atomic)

        // Make run-hook.sh executable (0o755)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.ccRunHook.path)
    }

    private func injectCCHooksIntoClaudeSettings() throws {
        let settingsURL = Self.ccSettingsPath
        var settings = try loadJSONObject(from: settingsURL)

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        for (event, matcher) in Self.ccHookEvents {
            let hookEntry: [String: Any] = [
                "matcher": matcher,
                "hooks": [
                    [
                        "type": "command",
                        "command": "\(Self.ccRunHookCommand) \(event)",
                    ] as [String: Any],
                ],
            ]

            // Merge into existing array for this event — avoid duplicates
            var eventEntries = hooks[event] as? [[String: Any]] ?? []
            let alreadyPresent = eventEntries.contains { entry in
                guard let innerHooks = entry["hooks"] as? [[String: Any]] else { return false }
                return innerHooks.contains { ($0["command"] as? String)?.contains("nekode") == true }
            }
            if !alreadyPresent {
                eventEntries.append(hookEntry)
            }
            hooks[event] = eventEntries
        }

        settings["hooks"] = hooks
        try writeJSONObject(settings, to: settingsURL)
    }

    private func removeCCHooksFromClaudeSettings() throws {
        let settingsURL = Self.ccSettingsPath
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }

        var settings = try loadJSONObject(from: settingsURL)
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for (event, _) in Self.ccHookEvents {
            guard var entries = hooks[event] as? [[String: Any]] else { continue }
            entries.removeAll { entry in
                guard let innerHooks = entry["hooks"] as? [[String: Any]] else { return false }
                return innerHooks.contains { ($0["command"] as? String)?.contains("nekode") == true }
            }
            if entries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = entries
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }
        try writeJSONObject(settings, to: settingsURL)
    }

    private func ccHooksInClaudeSettings() -> Bool {
        guard let settings = try? loadJSONObject(from: Self.ccSettingsPath),
              let hooks = settings["hooks"] as? [String: Any],
              let sessionStart = hooks["SessionStart"] as? [[String: Any]] else {
            return false
        }
        // Check if any SessionStart entry has our nekode command
        return sessionStart.contains { entry in
            guard let innerHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return innerHooks.contains { ($0["command"] as? String)?.contains("nekode") == true }
        }
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

    // MARK: - Copilot CLI

    func installCopilotCLIHooks() -> Bool {
        defer { refresh() }

        do {
            try installCopilotCLIHookFiles()
            logger.info("Installed Copilot CLI hooks")
            return true
        } catch {
            logger.error("Failed to install Copilot CLI hooks: \(error, privacy: .public)")
            return false
        }
    }

    func removeCopilotCLIHooks() -> Bool {
        defer { refresh() }

        do {
            // Remove hooks.json from ~/.copilot/hooks/
            let nekodeHooksJSON = Self.copilotCLIUserHooksDir.appendingPathComponent("nekode-hooks.json")
            if FileManager.default.fileExists(atPath: nekodeHooksJSON.path) {
                try FileManager.default.removeItem(at: nekodeHooksJSON)
            }

            // Remove our plugin directory
            let pluginDir = Self.copilotCLIHooksDir.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: pluginDir.path) {
                try FileManager.default.removeItem(at: pluginDir)
            }

            logger.info("Removed Copilot CLI hooks")
            return true
        } catch {
            logger.error("Failed to remove Copilot CLI hooks: \(error, privacy: .public)")
            return false
        }
    }

    private func installCopilotCLIHookFiles() throws {
        let fm = FileManager.default

        // 1. Copy hook files to ~/.nekode/plugins/copilot-cli/hooks/
        try fm.createDirectory(at: Self.copilotCLIHooksDir, withIntermediateDirectories: true)

        guard let bundledHooksJSON = Bundle.main.url(forResource: "copilot-cli-hooks", withExtension: "json"),
              let bundledRunHook = Bundle.main.url(forResource: "copilot-cli-run-hook", withExtension: "sh") else {
            throw PluginError.bundledResourceMissing
        }

        let hooksData = try Data(contentsOf: bundledHooksJSON)
        try hooksData.write(to: Self.copilotCLIHooksJSON, options: .atomic)

        let runHookData = try Data(contentsOf: bundledRunHook)
        try runHookData.write(to: Self.copilotCLIRunHook, options: .atomic)

        // Make run-hook.sh executable (0o755)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.copilotCLIRunHook.path)

        // 2. Place hooks.json in ~/.copilot/hooks/ so Copilot CLI picks it up.
        // We use a separate filename (nekode-hooks.json) to avoid overwriting user hooks.
        try fm.createDirectory(at: Self.copilotCLIUserHooksDir, withIntermediateDirectories: true)
        let destHooksJSON = Self.copilotCLIUserHooksDir.appendingPathComponent("nekode-hooks.json")
        try hooksData.write(to: destHooksJSON, options: .atomic)
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
        // If the file doesn't exist yet (e.g. fresh VS Code install), start with empty object
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
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
        // Ensure parent directory exists (e.g. fresh VS Code install)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
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
        // swiftlint:disable:next force_try
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
