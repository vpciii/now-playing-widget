import Foundation
import NowPlayingCore

/// The queue source (ADR-0001): runs the bundled script through Xcode's
/// Apple-signed `swift` interpreter and parses what it prints.
struct SwiftScriptQueueSource {
    static let interpreter = URL(fileURLWithPath: "/usr/bin/swift")
    static let timeout: TimeInterval = 3

    /// Runs the script off the main thread and calls back on the main thread.
    func fetch(completion: @escaping (QueueResult) -> Void) {
        guard let script = Bundle.main.url(forResource: "queue-source", withExtension: "swiftscript"),
              let source = try? FileHandle(forReadingFrom: script) else {
            completion(.failed(reason: "script missing from the app bundle"))
            return
        }
        guard FileManager.default.isExecutableFile(atPath: Self.interpreter.path) else {
            completion(.failed(reason: "swift interpreter not installed"))
            return
        }

        let process = Process()
        process.executableURL = Self.interpreter
        // "-" makes the interpreter read the program from standard input.
        process.arguments = ["-"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.standardInput = source

        DispatchQueue.global(qos: .userInitiated).async {
            var timedOut = false
            let deadline = DispatchWorkItem {
                timedOut = true
                process.terminate()
            }
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async { completion(.failed(reason: "could not start: \(error.localizedDescription)")) }
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.timeout, execute: deadline)
            let output = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            deadline.cancel()
            let result = QueueOutputParser.parse(stdout: output, exitCode: process.terminationStatus, timedOut: timedOut)
            DispatchQueue.main.async { completion(result) }
        }
    }
}
