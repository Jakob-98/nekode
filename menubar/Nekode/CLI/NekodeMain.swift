import Foundation

/// Unified CLI entry point for Nekode.
///
/// Subcommands:
///   nekode hook [--source <source>] <HookName>   — session hook
///   nekode wait [--name <n>] [--project <p>]      — pipe monitor
///   nekode                                         — implicit wait when stdin is a pipe
///
/// Called by Claude Code / VS Code Copilot hooks, or piped from any command.
@main
struct NekodeMain {
    static let version = "1.0.0"

    static func main() {
        let args = CommandLine.arguments

        // No arguments: if stdin is a pipe, default to wait mode
        if args.count < 2 {
            if !isatty(STDIN_FILENO).boolValue {
                WaitCommand.run(args: Array(args.dropFirst()))
            } else {
                printTopLevelHelp()
                exit(0)
            }
            return
        }

        switch args[1] {
        case "hook":
            HookCommand.run(args: Array(args.dropFirst(2)))
        case "wait":
            WaitCommand.run(args: Array(args.dropFirst(2)))
        case "--version", "-V":
            print("nekode \(version)")
            exit(0)
        case "--help", "-h":
            printTopLevelHelp()
            exit(0)
        default:
            // If first arg looks like a flag (e.g. --name), treat as implicit wait
            if args[1].hasPrefix("-") && !isatty(STDIN_FILENO).boolValue {
                WaitCommand.run(args: Array(args.dropFirst()))
            } else {
                FileHandle.standardError.write(
                    Data("nekode: unknown command '\(args[1])'\n".utf8))
                printTopLevelHelp()
                exit(1)
            }
        }
    }

    private static func printTopLevelHelp() {
        print("nekode \(version)")
        print("Desktop cats for your coding agents.\n")
        print("USAGE:")
        print("    nekode <COMMAND> [OPTIONS]\n")
        print("COMMANDS:")
        print("    hook    Handle session hooks (Claude Code, Copilot)")
        print("    wait    Monitor a piped command as a live session\n")
        print("PIPE MODE:")
        print("    some_command | nekode [--name <name>]\n")
        print("OPTIONS:")
        print("    -h, --help       Print this help message")
        print("    -V, --version    Print version")
    }
}

// MARK: - Hook Subcommand

enum HookCommand {
    static func run(args: [String]) {
        guard !args.isEmpty else {
            HookLogger.logError("missing hook name argument")
            exit(0)
        }

        switch args[0] {
        case "--version", "-V":
            print("nekode hook \(NekodeMain.version)")
            exit(0)
        case "--help", "-h":
            printHelp()
            exit(0)
        default:
            break
        }

        // Parse optional --source flag
        var sourceRaw: String?
        var hookName: String

        if args[0] == "--source" {
            guard args.count >= 3 else {
                HookLogger.logError("--source requires a value and a hook name")
                exit(0)
            }
            sourceRaw = args[1]
            hookName = args[2]
        } else {
            hookName = args[0]
        }

        let source = sourceRaw.flatMap(SessionSource.init(rawValue:))

        guard let stdinBuf = readStdin(hookName: hookName) else { exit(0) }

        let input: HookInput
        do {
            input = try JSONDecoder().decode(HookInput.self, from: Data(stdinBuf.utf8))
        } catch {
            HookLogger.logError("\(hookName): failed to parse JSON: \(error)")
            exit(0)
        }

        do {
            try HookHandler.handleHook(hookName: hookName, input: input, source: source)
        } catch {
            HookLogger.logError("\(hookName): \(error)")
            exit(0)
        }
    }

    private static func readStdin(hookName: String) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error> = .success("")

        DispatchQueue.global().async {
            do {
                let data = try FileHandle.standardInput.readToEnd() ?? Data()
                result = .success(String(data: data, encoding: .utf8) ?? "")
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + 5) == .success else {
            HookLogger.logError("\(hookName): stdin read timed out after 5s")
            return nil
        }

        switch result {
        case .success(let text):
            return text
        case .failure(let error):
            HookLogger.logError("\(hookName): failed to read stdin: \(error)")
            return nil
        }
    }

    private static func printHelp() {
        print("nekode hook \(NekodeMain.version)")
        print("Hook handler for Nekode session tracking.\n")
        print("This subcommand is called by Claude Code, VS Code Copilot, and Copilot CLI hooks")
        print("via the Nekode plugin. It reads hook event JSON from stdin")
        print("and updates session files in ~/.nekode/sessions/.\n")
        print("USAGE:")
        print("    nekode hook [--source <SOURCE>] <HOOK_NAME>\n")
        print("HOOK NAMES:")
        print("    SessionStart, UserPromptSubmit, PreToolUse, PostToolUse,")
        print("    Stop, Notification, PermissionRequest, PreCompact, SessionEnd\n")
        print("OPTIONS:")
        print("    --source <SOURCE>  Set session source (e.g. copilot, opencode)")
        print("    -h, --help         Print this help message")
        print("    -V, --version      Print version")
    }
}

// MARK: - Wait Subcommand

enum WaitCommand {
    static func run(args: [String]) {
        // Parse flags
        var name: String?
        var projectPath: String?
        var idx = 0
        while idx < args.count {
            switch args[idx] {
            case "--version", "-V":
                print("nekode wait \(NekodeMain.version)")
                exit(0)
            case "--help", "-h":
                printHelp()
                exit(0)
            case "--name":
                guard idx + 1 < args.count else {
                    FileHandle.standardError.write(
                        Data("nekode: --name requires a value\n".utf8))
                    exit(1)
                }
                idx += 1
                name = args[idx]
            case "--project":
                guard idx + 1 < args.count else {
                    FileHandle.standardError.write(
                        Data("nekode: --project requires a value\n".utf8))
                    exit(1)
                }
                idx += 1
                projectPath = args[idx]
            default:
                FileHandle.standardError.write(
                    Data("nekode: unknown option '\(args[idx])'\n".utf8))
                printHelp()
                exit(1)
            }
            idx += 1
        }

        // Resolve project
        let project = resolveProjectPath(projectPath)
        let branch = getCurrentBranch(cwd: project)
        let sessionName = name ?? detectParentCommand()

        // Create session
        let pid = ProcessInfo.processInfo.processIdentifier
        let startTime = Session.processStartTime(pid: UInt32(pid))
        let sessionsDir = Config.sessionsDir()
        let sessionPath = (sessionsDir as NSString)
            .appendingPathComponent("\(pid).json")

        let terminalInfo = detectTerminalInfo()

        var session = Session(
            sessionId: "nekode-\(pid)",
            projectPath: project,
            projectName: Session.extractProjectName(project),
            branch: branch,
            status: .working,
            lastPrompt: nil,
            lastActivity: Date(),
            startedAt: Date(),
            terminal: terminalInfo,
            pid: UInt32(pid),
            pidStartTime: startTime,
            lastTool: "pipe",
            lastToolDetail: sessionName ?? "reading stdin...",
            notificationMessage: nil,
            sessionName: sessionName,
            source: .cli
        )

        // Write initial session
        do {
            try session.writeToFile(path: sessionPath)
        } catch {
            FileHandle.standardError.write(
                Data("nekode: failed to write session: \(error)\n".utf8))
            exit(1)
        }

        // Set up cleanup on exit
        func cleanup() {
            try? FileManager.default.removeItem(atPath: sessionPath)
        }

        signal(SIGINT) { _ in
            try? FileManager.default.removeItem(
                atPath: (Config.sessionsDir() as NSString)
                    .appendingPathComponent(
                        "\(ProcessInfo.processInfo.processIdentifier).json"))
            exit(0)
        }

        signal(SIGTERM) { _ in
            try? FileManager.default.removeItem(
                atPath: (Config.sessionsDir() as NSString)
                    .appendingPathComponent(
                        "\(ProcessInfo.processInfo.processIdentifier).json"))
            exit(0)
        }

        // Run the pipe passthrough
        let monitor = PipeMonitor(session: session, sessionPath: sessionPath)
        monitor.run()

        // stdin EOF reached — command finished
        session.status = .waitingInput
        session.lastActivity = Date()
        session.lastTool = nil
        session.lastToolDetail = nil
        session.notificationMessage = "Command finished"
        try? session.writeToFile(path: sessionPath)

        // Block until user presses Enter or Ctrl+C
        FileHandle.standardError.write(
            Data("\nnekode: command finished. Press Enter to dismiss.\n".utf8))

        // Read one line from /dev/tty (not stdin, which is the pipe)
        if let tty = fopen("/dev/tty", "r") {
            var line: UnsafeMutablePointer<CChar>?
            var linecap: Int = 0
            _ = getline(&line, &linecap, tty)
            free(line)
            fclose(tty)
        } else {
            // No tty available (e.g. running in background) — wait 30s then exit
            Thread.sleep(forTimeInterval: 30)
        }

        cleanup()
    }

    // MARK: - Helpers

    private static func detectTerminalInfo() -> TerminalInfo {
        let env = ProcessInfo.processInfo.environment
        let program = env["TERM_PROGRAM"] ?? ""

        let sessionId: String? = {
            let raw = env["ITERM_SESSION_ID"] ?? env["KITTY_WINDOW_ID"]
            guard let raw, !raw.isEmpty,
                  raw.range(of: #"^[0-9a-zA-Z:.@_-]+$"#, options: .regularExpression) != nil
            else { return nil }
            return raw
        }()

        let tty: String? = {
            if let t = env["TTY"], !t.isEmpty { return t }
            var pid = getppid()
            for _ in 0..<6 {
                if pid <= 1 { break }
                var info = kinfo_proc()
                var size = MemoryLayout<kinfo_proc>.size
                var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
                guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { break }
                let tdev = info.kp_eproc.e_tdev
                if tdev != UInt32.max, let name = devname(tdev, S_IFCHR) {
                    return "/dev/" + String(cString: name)
                }
                pid = info.kp_eproc.e_ppid
            }
            return nil
        }()

        return TerminalInfo(program: program, sessionId: sessionId, tty: tty)
    }

    private static func resolveProjectPath(_ explicit: String?) -> String {
        if let explicit {
            let url = URL(fileURLWithPath: explicit, relativeTo: URL(
                fileURLWithPath: FileManager.default.currentDirectoryPath))
            return url.standardized.path
        }
        return FileManager.default.currentDirectoryPath
    }

    private static func getCurrentBranch(cwd: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["branch", "--show-current"]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "unknown" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let branch = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return branch.isEmpty ? "unknown" : branch
        } catch {
            return "unknown"
        }
    }

    private static func detectParentCommand() -> String? {
        let ppid = getppid()
        guard ppid > 1 else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "command=", "-p", "\(ppid)"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let cmd = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if cmd.isEmpty { return nil }
            return cmd
        } catch {
            return nil
        }
    }

    private static func printHelp() {
        print("nekode wait \(NekodeMain.version)")
        print("Pipe-based session monitoring for Nekode.\n")
        print("Pipe any long-running command through nekode to track it")
        print("as a live session in the Nekode menubar and desktop cats.\n")
        print("USAGE:")
        print("    some_command | nekode [wait] [OPTIONS]\n")
        print("EXAMPLES:")
        print("    cargo build --release 2>&1 | nekode")
        print("    npm run build | nekode --name \"npm build\"")
        print(
            "    make test 2>&1 | nekode wait --name \"tests\" --project ~/myapp\n")
        print("OPTIONS:")
        print("    --name <name>       Display name for the session")
        print("    --project <path>    Project directory (default: cwd)")
        print("    -h, --help          Print this help message")
        print("    -V, --version       Print version")
    }
}

// MARK: - Int32 Bool helper
private extension Int32 {
    var boolValue: Bool { self != 0 }
}
