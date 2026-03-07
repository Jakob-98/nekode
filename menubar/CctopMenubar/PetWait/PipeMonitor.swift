import Foundation

/// Reads stdin and passes it through to stdout, updating the session file
/// periodically to keep `last_activity` fresh. Returns when stdin reaches EOF.
final class PipeMonitor {
    private var session: Session
    private let sessionPath: String
    private let activityInterval: TimeInterval = 5.0
    private var lastWrite: Date

    init(session: Session, sessionPath: String) {
        self.session = session
        self.sessionPath = sessionPath
        self.lastWrite = Date()
    }

    /// Runs the stdin→stdout passthrough loop. Blocks until EOF.
    func run() {
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput
        let bufferSize = 8192

        while true {
            let data = stdin.readData(ofLength: bufferSize)
            if data.isEmpty {
                // EOF — upstream command finished
                break
            }

            // Passthrough to stdout
            stdout.write(data)

            // Periodically update last_activity so the session doesn't look stale
            let now = Date()
            if now.timeIntervalSince(lastWrite) >= activityInterval {
                session.lastActivity = now
                try? session.writeToFile(path: sessionPath)
                lastWrite = now
            }
        }
    }
}
