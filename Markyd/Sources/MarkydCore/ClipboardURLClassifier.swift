import Foundation

public enum ClipboardURLKind: Equatable, Sendable {
    case webpage(URL)
    case pdf(URL)
}

public struct ClipboardURLClassifier: Sendable {
    public init() {}

    public func classify(_ rawValue: String) -> ClipboardURLKind? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let url = URL(string: trimmed) else { return nil }
        return self.classify(url)
    }

    public func classify(_ url: URL) -> ClipboardURLKind? {
        guard self.isSupportedURL(url) else { return nil }

        if let rewrittenPDF = self.rewrittenPDFURL(for: url) {
            return .pdf(rewrittenPDF)
        }

        if self.looksLikePDF(url) {
            return .pdf(url)
        }

        return .webpage(url)
    }

    public func looksLikePDF(_ url: URL) -> Bool {
        if url.isFileURL {
            return url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame
        }

        if url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
            return true
        }

        let absolute = url.absoluteString.lowercased()
        if absolute.contains(".pdf?") || absolute.contains("format=pdf") || absolute.contains("download=pdf") {
            return true
        }

        return false
    }

    public func rewrittenPDFURL(for url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }

        if host == "arxiv.org" || host == "www.arxiv.org" {
            let path = url.path
            if path.hasPrefix("/abs/") {
                let identifier = String(path.dropFirst("/abs/".count))
                guard !identifier.isEmpty else { return nil }
                return URL(string: "https://arxiv.org/pdf/\(identifier).pdf")
            }
        }

        return nil
    }

    private func isSupportedURL(_ url: URL) -> Bool {
        if url.isFileURL {
            return true
        }

        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
