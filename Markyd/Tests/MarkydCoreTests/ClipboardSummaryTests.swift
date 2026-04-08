import Foundation
import MarkydCore
import Testing

struct ClipboardSummaryTests {
    @Test("Summarizes long clipboard text")
    func summarizesLongText() {
        let value = String(repeating: "a", count: 80)
        let summary = ClipboardSummary.summarize(value, limit: 10)

        #expect(summary == "aaaaaaaaa…")
    }
}
