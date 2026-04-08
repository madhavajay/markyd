import Foundation

public struct MarkdownFormatting: Sendable {
    public init() {}

    public func wrapWebMarkdown(_ markdown: String, sourceURL: URL) -> String {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "[Source](\(sourceURL.absoluteString))"
        }

        return """
        Source: <\(sourceURL.absoluteString)>

        \(trimmed)
        """
    }

    public func wrapPDFText(_ text: String, sourceURL: URL) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        Source: <\(sourceURL.absoluteString)>

        \(trimmed)
        """
    }
}
