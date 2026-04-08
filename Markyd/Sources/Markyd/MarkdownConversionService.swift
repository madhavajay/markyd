import Demark
import Foundation
import MarkydCore
import PDFKit

struct MarkdownConversionResult: Sendable {
    let markdown: String
    let sourceURL: URL
    let route: ClipboardURLKind
    let sourceArtifact: HistoryArtifact?
}

actor MarkdownConversionService {
    private let classifier = ClipboardURLClassifier()
    private let formatter = MarkdownFormatting()
    private let pdfConverter: any PDFMarkdownConverting
    private let session: URLSession

    init(
        pdfConverter: any PDFMarkdownConverting = PDFKitMarkdownConverter(),
        session: URLSession = .shared
    ) {
        self.pdfConverter = pdfConverter
        self.session = session
    }

    func convertClipboardValue(_ rawValue: String) async throws -> MarkdownConversionResult {
        guard let route = self.classifier.classify(rawValue) else {
            throw MarkdownConversionError.invalidClipboardContents
        }
        return try await self.convert(route: route)
    }

    func convertClipboardURL(_ url: URL) async throws -> MarkdownConversionResult {
        guard let route = self.classifier.classify(url) else {
            throw MarkdownConversionError.invalidClipboardContents
        }
        return try await self.convert(route: route)
    }

    private func convert(route: ClipboardURLKind) async throws -> MarkdownConversionResult {
        switch route {
        case let .webpage(url):
            let fetched = try await self.fetchHTML(from: url)
            let demark = await MainActor.run { Demark() }
            let markdown = try await demark.convertToMarkdown(
                fetched.html,
                options: DemarkOptions(engine: .htmlToMd)
            )
            return MarkdownConversionResult(
                markdown: self.formatter.wrapWebMarkdown(markdown, sourceURL: url),
                sourceURL: url,
                route: route,
                sourceArtifact: HistoryArtifact(kind: .html, data: fetched.data)
            )
        case let .pdf(url):
            let data = try await self.fetchPDFData(from: url)
            let markdown = try await self.pdfConverter.convert(data: data, sourceURL: url)
            return MarkdownConversionResult(
                markdown: markdown,
                sourceURL: url,
                route: route,
                sourceArtifact: HistoryArtifact(kind: .pdf, data: data)
            )
        }
    }

    private func fetchHTML(from url: URL) async throws -> FetchedHTML {
        if url.isFileURL {
            let data = try Data(contentsOf: url)
            return FetchedHTML(html: try self.decodeHTML(data, response: nil), data: data)
        }

        let (data, response) = try await self.session.data(from: url)

        if self.isPDFResponse(url: url, response: response, data: data) {
            throw MarkdownConversionError.expectedPDF
        }

        return FetchedHTML(html: try self.decodeHTML(data, response: response), data: data)
    }

    private func fetchPDFData(from url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        let (data, response) = try await self.session.data(from: url)
        guard self.isPDFResponse(url: url, response: response, data: data) else {
            throw MarkdownConversionError.expectedPDF
        }
        return data
    }

    private func decodeHTML(_ data: Data, response: URLResponse?) throws -> String {
        if let response, let encodingName = response.textEncodingName,
           let encoding = String.Encoding(ianaCharsetName: encodingName),
           let html = String(data: data, encoding: encoding)
        {
            return html
        }

        if let html = String(data: data, encoding: .utf8) {
            return html
        }

        if let html = String(data: data, encoding: .isoLatin1) {
            return html
        }

        throw MarkdownConversionError.unreadableHTML
    }

    private func isPDFResponse(url: URL, response: URLResponse?, data: Data) -> Bool {
        if self.classifier.looksLikePDF(url) {
            return true
        }

        if let mimeType = response?.mimeType?.lowercased(), mimeType.contains("pdf") {
            return true
        }

        return data.starts(with: Data("%PDF".utf8))
    }
}

private struct FetchedHTML: Sendable {
    let html: String
    let data: Data
}

enum MarkdownConversionError: LocalizedError {
    case invalidClipboardContents
    case expectedPDF
    case unreadableHTML

    var errorDescription: String? {
        switch self {
        case .invalidClipboardContents:
            "Clipboard does not contain a supported URL."
        case .expectedPDF:
            "The document route resolved to PDF, but the fetched content was not a PDF."
        case .unreadableHTML:
            "The page could not be decoded as HTML."
        }
    }
}

extension String.Encoding {
    fileprivate init?(ianaCharsetName: String) {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(ianaCharsetName as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        self.init(rawValue: nsEncoding)
    }
}

struct PDFKitMarkdownConverter: PDFMarkdownConverting {
    private let formatter = MarkdownFormatting()

    func convert(data: Data, sourceURL: URL) async throws -> String {
        guard let document = PDFDocument(data: data) else {
            throw PDFMarkdownError.unsupportedDocument
        }

        var sections: [String] = []
        for pageIndex in 0 ..< document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            let text = (page.string ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            sections.append("## Page \(pageIndex + 1)\n\n\(text)")
        }

        let body = sections.joined(separator: "\n\n")
        guard !body.isEmpty else {
            throw PDFMarkdownError.emptyDocument
        }

        return self.formatter.wrapPDFText(body, sourceURL: sourceURL)
    }
}
