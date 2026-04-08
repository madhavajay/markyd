import Foundation
import MarkydCore
import Testing

struct MarkdownFormattingTests {
    @Test("Wraps web markdown with source link")
    func wrapsWebMarkdown() {
        let formatter = MarkdownFormatting()
        let result = formatter.wrapWebMarkdown("# Title", sourceURL: URL(string: "https://example.com")!)

        #expect(result.contains("Source: <https://example.com>"))
        #expect(result.contains("# Title"))
    }

    @Test("Derives markdown sibling path for PDFs")
    func derivesMarkdownSiblingPath() {
        let source = URL(filePath: "/tmp/papers/example.pdf")
        let output = MarkdownFileNaming.outputURL(for: source)

        #expect(output.path == "/tmp/papers/example.md")
    }
}
