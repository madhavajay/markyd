import Foundation
import MarkydCore
import Testing

struct ClipboardURLClassifierTests {
    @Test("Rejects invalid clipboard text")
    func rejectsInvalidText() {
        let classifier = ClipboardURLClassifier()

        #expect(classifier.classify("not a url") == nil)
    }

    @Test("Classifies normal webpages")
    func classifiesWebpages() {
        let classifier = ClipboardURLClassifier()

        #expect(classifier.classify("https://example.com/article") == .webpage(URL(string: "https://example.com/article")!))
    }

    @Test("Classifies direct PDF URLs")
    func classifiesDirectPDFURLs() {
        let classifier = ClipboardURLClassifier()

        #expect(classifier.classify("https://example.com/paper.pdf") == .pdf(URL(string: "https://example.com/paper.pdf")!))
    }

    @Test("Rewrites arXiv abstract URLs to PDFs")
    func rewritesArxivAbstractURLs() {
        let classifier = ClipboardURLClassifier()

        #expect(classifier.classify("https://arxiv.org/abs/2401.01234") == .pdf(URL(string: "https://arxiv.org/pdf/2401.01234.pdf")!))
    }

    @Test("Classifies local PDFs")
    func classifiesLocalPDFs() {
        let classifier = ClipboardURLClassifier()

        #expect(classifier.classify(URL(filePath: "/tmp/test.pdf")) == .pdf(URL(filePath: "/tmp/test.pdf")))
    }
}
