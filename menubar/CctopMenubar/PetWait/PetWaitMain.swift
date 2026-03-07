import Foundation

/// CLI entry point for petwait.
///
/// Pipe any long-running command through petwait to monitor it as a cctop session.
/// When the command finishes (stdin EOF), the session transitions to waiting_input
/// so the desktop pet alerts you and the menubar shows it needs attention.
///
/// Usage: some_command | petwait [--name <name>] [--project <path>]
@main
struct PetWaitMain {
    static let version = "0.7.2"

    static func main() {
        let args = CommandLine.arguments

        // Parse flags
        var name: String?
        var projectPath: String?
        var idx = 1
        while idx < args.count {
            switch args[idx] {
            case "--version", "-V":
                print("petwait \(version)")
                exit(0)
            case "--help", "-h":
                printHelp()
                exit(0)
            case "--name":
                guard idx + 1 < args.count else {
                    FileHandle.standardError.write(
                        Data("petwait: --name requires a value\n".utf8))
                    exit(1)
                }
                idx += 1
                name = args[idx]
            case "--project":
                guard idx + 1 < args.count else {
                    FileHandle.standardError.write(
                        Data("petwait: --project requires a value\n".utf8))
                    exit(1)
                }
                idx += 1
                projectPath = args[idx]
            default:
                FileHandle.standardError.write(
                    Data("petwait: unknown option '\(args[idx])'\n".utf8))
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
            sessionId: "petwait-\(pid)",
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
            source: "cli"
        )

        // Write initial session
        do {
            try session.writeToFile(path: sessionPath)
        } catch {
            FileHandle.standardError.write(
                Data("petwait: failed to write session: \(error)\n".utf8))
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
            Data("\npetwait: command finished. Press Enter to dismiss.\n".utf8))

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

    /// Detect the terminal app hosting this petwait process via environment
    /// variables, mirroring cctop-hook's captureTerminalInfo().
    private static func detectTerminalInfo() -> TerminalInfo? {
        let env = ProcessInfo.processInfo.environment
        let program = env["TERM_PROGRAM"] ?? ""
        guard !program.isEmpty else { return nil }

        // iTerm2 / Kitty session ID for tab-level focus
        let sessionId: String? = {
            let raw = env["ITERM_SESSION_ID"] ?? env["KITTY_WINDOW_ID"]
            guard let raw, !raw.isEmpty,
                  raw.range(of: #"^[0-9a-zA-Z:.@_-]+$"#, options: .regularExpression) != nil
            else { return nil }
            return raw
        }()

        // TTY from env or proc info
        let tty: String? = {
            if let t = env["TTY"], !t.isEmpty { return t }
            // Walk parent chain to find a TTY (same approach as HookHandler)
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
            // Resolve relative paths
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

    /// Try to detect what command is piping into us by inspecting the parent
    /// process tree. Falls back to nil.
    private static func detectParentCommand() -> String? {
        let ppid = getppid()
        guard ppid > 1 else { return nil }

        // Try to get the command line of the parent's children (our siblings in the pipeline)
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
            // The parent is usually the shell; not very useful
            // Return nil and let the user use --name
            return nil
        } catch {
            return nil
        }
    }

    private static func printHelp() {
        print("petwait \(version)")
        print("Pipe-based session monitoring for cctop.\n")
        print("Pipe any long-running command through petwait to track it")
        print("as a live session in the cctop menubar and desktop pets.\n")
        print("USAGE:")
        print("    some_command | petwait [OPTIONS]\n")
        print("EXAMPLES:")
        print("    cargo build --release 2>&1 | petwait")
        print("    npm run build | petwait --name \"npm build\"")
        print(
            "    make test 2>&1 | petwait --name \"tests\" --project ~/myapp\n")
        print("OPTIONS:")
        print("    --name <name>       Display name for the session")
        print("    --project <path>    Project directory (default: cwd)")
        print("    -h, --help          Print this help message")
        print("    -V, --version       Print version")
    }
}
