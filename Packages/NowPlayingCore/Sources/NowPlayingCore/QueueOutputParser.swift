import Foundation

/// Turns one run of the queue source script into a `QueueResult`.
/// Contract (plan, "API changes"): exit 0 with
/// `{"items":[{"title","artist","album","artworkURL"}...]}`; anything else
/// is a failure.
public enum QueueOutputParser {
    private struct Output: Decodable {
        var items: [QueueItem]
    }

    public static func parse(stdout: Data, exitCode: Int32, timedOut: Bool) -> QueueResult {
        if timedOut { return .failed(reason: "timed out") }
        guard exitCode == 0 else { return .failed(reason: "exit code \(exitCode)") }
        guard let output = try? JSONDecoder().decode(Output.self, from: stdout) else {
            return .failed(reason: "malformed output")
        }
        return .items(output.items)
    }
}
