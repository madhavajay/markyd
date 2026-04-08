import Foundation

public protocol PDFMarkdownConverting: Sendable {
    func convert(data: Data, sourceURL: URL) async throws -> String
}

public enum PDFMarkdownError: LocalizedError, Sendable {
    case emptyDocument
    case unsupportedDocument

    public var errorDescription: String? {
        switch self {
        case .emptyDocument:
            "The PDF did not contain extractable text."
        case .unsupportedDocument:
            "The document could not be converted to Markdown."
        }
    }
}
