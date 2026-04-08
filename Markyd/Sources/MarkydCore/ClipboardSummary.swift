import Foundation

public enum ClipboardSummary {
    public static func summarize(_ text: String, limit: Int = 64) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let prefix = trimmed.prefix(limit - 1)
        return "\(prefix)…"
    }
}
