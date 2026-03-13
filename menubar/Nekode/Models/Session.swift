import Foundation

// MARK: - Session Source

/// Identifies which coding tool produced a session.
/// Raw values match the JSON strings written by hook scripts and plugins.
enum SessionSource: String, Codable, Equatable {
    case claude         // Claude Code (default when source is nil/absent)
    case copilot        // VS Code Copilot
    case copilotCLI = "copilot-cli"  // GitHub Copilot CLI
    case opencode       // opencode
    case cli            // nekode wait / pipe-based

    /// Short label for the menubar UI badge.
    var label: String {
        switch self {
        case .claude:     return "CC"
        case .copilot:    return "CP"
        case .copilotCLI: return "GH"
        case .opencode:   return "OC"
        case .cli:        return "CLI"
        }
    }

    /// Whether this source uses Copilot-style lifecycle (no Notification hooks,
    /// Stop means waiting-for-input, inactivity timeout for staleness).
    var isCopilotFamily: Bool {
        self == .copilot || self == .copilotCLI
    }

    /// Key used for per-source pet toggle in UserDefaults.
    /// Maps nil (Claude Code) to "claude" so UserDefaults always has a string key.
    var petToggleKey: String { rawValue }

    /// Resolve a nil source to its default (Claude Code).
    static func resolve(_ source: SessionSource?) -> SessionSource {
        source ?? .claude
    }
}

// MARK: - Shared date formatting

extension Date {
    var relativeDescription: String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds <= 0 { return "just now" }
        if seconds >= 86400 { return "\(seconds / 86400)d ago" }
        if seconds >= 3600 { return "\(seconds / 3600)h ago" }
        if seconds >= 60 { return "\(seconds / 60)m ago" }
        return "\(seconds)s ago"
    }
}

extension JSONEncoder {
    static let sessionEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }()
}

extension JSONDecoder {
    static let sessionDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFractional.date(from: string) { return date }
            if let date = withoutFractional.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }()
}

struct TerminalInfo: Codable {
    let program: String
    let sessionId: String?
    let tty: String?

    enum CodingKeys: String, CodingKey {
        case program
        case sessionId = "session_id"
        case tty
    }

    init(program: String = "", sessionId: String? = nil, tty: String? = nil) {
        self.program = program
        self.sessionId = sessionId
        self.tty = tty
    }
}

struct Session: Codable, Identifiable {
    let sessionId: String
    let projectPath: String
    let projectName: String
    var branch: String
    var status: SessionStatus
    var lastPrompt: String?
    var lastActivity: Date
    var startedAt: Date
    var terminal: TerminalInfo?
    var pid: UInt32?
    var pidStartTime: TimeInterval?
    var lastTool: String?
    var lastToolDetail: String?
    var notificationMessage: String?
    var sessionName: String?
    var workspaceFile: String?
    var source: SessionSource?
    var endedAt: Date?

    var id: String { pid.map { String($0) } ?? sessionId }

    var displayName: String {
        sessionName ?? projectName
    }

    var sourceLabel: String {
        SessionSource.resolve(source).label
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case projectPath = "project_path"
        case projectName = "project_name"
        case branch, status
        case lastPrompt = "last_prompt"
        case lastActivity = "last_activity"
        case startedAt = "started_at"
        case terminal, pid
        case pidStartTime = "pid_start_time"
        case lastTool = "last_tool"
        case lastToolDetail = "last_tool_detail"
        case notificationMessage = "notification_message"
        case sessionName = "session_name"
        case workspaceFile = "workspace_file"
        case source
        case endedAt = "ended_at"
    }

    // Custom decoder: unknown `source` strings (e.g. "aider") decode as nil
    // instead of throwing, so sessions from future/unknown tools still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try c.decode(String.self, forKey: .sessionId)
        projectPath = try c.decode(String.self, forKey: .projectPath)
        projectName = try c.decode(String.self, forKey: .projectName)
        branch = try c.decode(String.self, forKey: .branch)
        status = try c.decode(SessionStatus.self, forKey: .status)
        lastPrompt = try c.decodeIfPresent(String.self, forKey: .lastPrompt)
        lastActivity = try c.decode(Date.self, forKey: .lastActivity)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        terminal = try c.decodeIfPresent(TerminalInfo.self, forKey: .terminal)
        pid = try c.decodeIfPresent(UInt32.self, forKey: .pid)
        pidStartTime = try c.decodeIfPresent(TimeInterval.self, forKey: .pidStartTime)
        lastTool = try c.decodeIfPresent(String.self, forKey: .lastTool)
        lastToolDetail = try c.decodeIfPresent(String.self, forKey: .lastToolDetail)
        notificationMessage = try c.decodeIfPresent(String.self, forKey: .notificationMessage)
        sessionName = try c.decodeIfPresent(String.self, forKey: .sessionName)
        workspaceFile = try c.decodeIfPresent(String.self, forKey: .workspaceFile)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        // Decode source as raw string first; map to enum. Unknown values → nil.
        if let raw = try c.decodeIfPresent(String.self, forKey: .source) {
            source = SessionSource(rawValue: raw)
        } else {
            source = nil
        }
    }

    // MARK: - Constructors

    /// Full memberwise init (used by mocks and tests).
    init(
        sessionId: String,
        projectPath: String,
        projectName: String,
        branch: String,
        status: SessionStatus,
        lastPrompt: String?,
        lastActivity: Date,
        startedAt: Date,
        terminal: TerminalInfo?,
        pid: UInt32?,
        pidStartTime: TimeInterval? = nil,
        lastTool: String?,
        lastToolDetail: String?,
        notificationMessage: String?,
        sessionName: String? = nil,
        workspaceFile: String? = nil,
        source: SessionSource? = nil,
        endedAt: Date? = nil
    ) {
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.projectName = projectName
        self.branch = branch
        self.status = status
        self.lastPrompt = lastPrompt
        self.lastActivity = lastActivity
        self.startedAt = startedAt
        self.terminal = terminal
        self.pid = pid
        self.pidStartTime = pidStartTime
        self.lastTool = lastTool
        self.lastToolDetail = lastToolDetail
        self.notificationMessage = notificationMessage
        self.sessionName = sessionName
        self.workspaceFile = workspaceFile
        self.source = source
        self.endedAt = endedAt
    }

    /// Convenience init for creating new sessions (used by nekode hook).
    init(sessionId: String, projectPath: String, branch: String, terminal: TerminalInfo) {
        self.sessionId = sessionId
        self.projectPath = projectPath
        self.projectName = Self.extractProjectName(projectPath)
        self.branch = branch
        self.status = .idle
        self.lastPrompt = nil
        self.lastActivity = Date()
        self.startedAt = Date()
        self.terminal = terminal
        self.pid = nil
        self.pidStartTime = nil
        self.lastTool = nil
        self.lastToolDetail = nil
        self.notificationMessage = nil
        self.sessionName = nil
        self.workspaceFile = nil
        self.source = nil
        self.endedAt = nil
    }

    // MARK: - File I/O

    static func fromFile(path: String) throws -> Session {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder.sessionDecoder.decode(Session.self, from: data)
    }

    func writeToFile(path: String) throws {
        let fm = FileManager.default
        let dir = (path as NSString).deletingLastPathComponent
        try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let data = try JSONEncoder.sessionEncoder.encode(self)
        let tempPath = path + ".tmp"
        let tempURL = URL(fileURLWithPath: tempPath)
        let destURL = URL(fileURLWithPath: path)
        try data.write(to: tempURL)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tempPath)

        // Atomic replace: rename(2) overwrites existing files on POSIX.
        // Foundation's moveItem does NOT, so use replaceItemAt or POSIX rename.
        if rename(tempPath, path) != 0 {
            // Fallback: remove + move
            try? fm.removeItem(at: destURL)
            try fm.moveItem(at: tempURL, to: destURL)
        }
    }

    // MARK: - Utilities

    static func sanitizeSessionId(raw: String) -> String {
        let filtered = String(raw.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_"
        })
        return String(filtered.prefix(64))
    }

    /// Returns a copy with a new session_id (and optionally updated branch/terminal).
    /// Used when the same OS process gets a new CC session_id on resume.
    func withSessionId(_ newId: String, branch: String? = nil, terminal: TerminalInfo? = nil) -> Session {
        Session(
            sessionId: newId,
            projectPath: projectPath,
            projectName: projectName,
            branch: branch ?? self.branch,
            status: status,
            lastPrompt: lastPrompt,
            lastActivity: lastActivity,
            startedAt: startedAt,
            terminal: terminal ?? self.terminal,
            pid: pid,
            pidStartTime: pidStartTime,
            lastTool: lastTool,
            lastToolDetail: lastToolDetail,
            notificationMessage: notificationMessage,
            sessionName: sessionName,
            workspaceFile: workspaceFile,
            source: source,
            endedAt: endedAt
        )
    }

    /// Look for a `.code-workspace` file in the given directory.
    /// If exactly one exists, return it. If multiple exist, prefer one matching the project name.
    static func findWorkspaceFile(in projectPath: String) -> String? {
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: projectPath) else {
            return nil
        }

        let workspaceFiles = entries.filter { $0.hasSuffix(".code-workspace") }
        if workspaceFiles.isEmpty { return nil }

        func fullPath(_ name: String) -> String {
            (projectPath as NSString).appendingPathComponent(name)
        }

        if workspaceFiles.count == 1 { return fullPath(workspaceFiles[0]) }

        // Multiple workspace files: prefer one matching the project folder name
        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        if let match = workspaceFiles.first(where: {
            ($0 as NSString).deletingPathExtension == projectName
        }) {
            return fullPath(match)
        }
        return nil
    }

    static func sorted(_ sessions: [Session]) -> [Session] {
        sessions.sorted {
            ($0.status.sortOrder, $1.lastActivity) < ($1.status.sortOrder, $0.lastActivity)
        }
    }

    static func extractProjectName(_ path: String) -> String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    static func processInfo(pid: UInt32) -> kinfo_proc? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0, size > 0 else { return nil }
        return info
    }

    static func processStartTime(pid: UInt32) -> TimeInterval? {
        guard let info = processInfo(pid: pid) else { return nil }
        return startTime(from: info)
    }

    /// Copilot sessions track a VS Code helper PID that may outlive the
    /// actual coding session (e.g. user closes a window but VS Code stays
    /// running). Copilot CLI sessions similarly persist between prompts.
    /// We consider them stale after 5 minutes of inactivity.
    private static let copilotInactivityTimeout: TimeInterval = 300

    var isAlive: Bool {
        guard let pid else { return false }
        guard kill(Int32(pid), 0) == 0 || errno == EPERM else { return false }
        guard let info = Self.processInfo(pid: pid) else { return false }

        // Check PID reuse: if we recorded a start time, verify it still matches
        if let stored = pidStartTime {
            let current = Self.startTime(from: info)
            if abs(stored - current) > 1.0 {
                return false
            }
        }

        // Orphan check: if parent is launchd (PPID=1), the terminal/IDE that
        // spawned this session has died. The process is alive but unreachable.
        if info.kp_eproc.e_ppid == 1 {
            return false
        }

        // Copilot inactivity check: the tracked PID is a VS Code helper process
        // (or Copilot CLI process) that may stay alive long after the user stops
        // interacting. If no hook activity for 5 minutes, consider the session stale.
        if SessionSource.resolve(source).isCopilotFamily,
           -lastActivity.timeIntervalSinceNow > Self.copilotInactivityTimeout {
            return false
        }

        return true
    }

    private static func startTime(from info: kinfo_proc) -> TimeInterval {
        let tv = info.kp_proc.p_starttime
        return TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000
    }

    /// The best available end-of-session timestamp: `endedAt` if archived, otherwise `lastActivity`.
    var effectiveEndDate: Date {
        endedAt ?? lastActivity
    }

    var relativeTime: String {
        lastActivity.relativeDescription
    }

    var contextLine: String? {
        switch status {
        case .idle: return nil
        case .compacting: return "Compacting context..."
        case .waitingPermission:
            return notificationMessage ?? "Permission needed"
        case .waitingInput, .needsAttention:
            return promptSnippet
        case .working:
            if let tool = lastTool {
                return formatToolDisplay(tool: tool, detail: lastToolDetail)
            }
            return promptSnippet
        }
    }

    private var promptSnippet: String? {
        lastPrompt.map { "\"\(String($0.prefix(36)))\"" }
    }

    private func formatToolDisplay(tool: String, detail: String?) -> String {
        guard let detail else { return "\(tool)..." }
        let fileName = URL(fileURLWithPath: detail).lastPathComponent
        switch tool.lowercased() {
        case "bash": return "Running: \(detail.prefix(30))"
        case "edit": return "Editing \(fileName)"
        case "write": return "Writing \(fileName)"
        case "read": return "Reading \(fileName)"
        case "grep": return "Searching: \(detail.prefix(30))"
        case "glob": return "Finding: \(detail.prefix(30))"
        case "webfetch": return "Fetching: \(detail.prefix(30))"
        case "websearch": return "Searching: \(detail.prefix(30))"
        case "task": return "Task: \(detail.prefix(30))"
        default: return "\(tool): \(detail.prefix(30))"
        }
    }
}
