import AppKit
import Foundation
import MarkydCore

enum HistoryAttemptStatus: String, Codable, Sendable {
    case succeeded
    case failed
}

enum HistoryArtifactKind: String, Codable, Sendable {
    case html
    case pdf
}

struct HistoryArtifact: Sendable {
    let kind: HistoryArtifactKind
    let data: Data
}

struct HistoryEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let createdAt: Date
    let status: HistoryAttemptStatus
    let rawClipboard: String
    let sourceURLString: String?
    let routeLabel: String?
    let statusMessage: String
    let directoryPath: String
    let clipboardFileName: String
    let markdownFileName: String?
    let sourceArtifactFileName: String?

    var sourceURL: URL? {
        self.sourceURLString.flatMap(URL.init(string:))
    }

    var directoryURL: URL {
        URL(fileURLWithPath: self.directoryPath, isDirectory: true)
    }

    var markdownFileURL: URL? {
        self.markdownFileName.map { self.directoryURL.appendingPathComponent($0) }
    }
}

struct HistoryArchiveRequest: Sendable {
    let rawClipboard: String
    let sourceURL: URL?
    let route: ClipboardURLKind?
    let status: HistoryAttemptStatus
    let statusMessage: String
    let markdown: String?
    let sourceArtifact: HistoryArtifact?
}

actor HistoryStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func save(_ request: HistoryArchiveRequest) async throws -> HistoryEntry {
        let id = UUID()
        let createdAt = Date()
        let directoryURL = try self.makeEntryDirectory(id: id, createdAt: createdAt)

        let clipboardFileName = "clipboard.txt"
        guard let clipboardData = request.rawClipboard.data(using: .utf8, allowLossyConversion: false) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try clipboardData.write(to: directoryURL.appendingPathComponent(clipboardFileName), options: .atomic)

        var markdownFileName: String?
        if let markdown = request.markdown {
            let fileName = "output.md"
            guard let markdownData = markdown.data(using: .utf8, allowLossyConversion: false) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            try markdownData.write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)
            markdownFileName = fileName
        }

        var sourceArtifactFileName: String?
        if let sourceArtifact = request.sourceArtifact {
            let fileName: String
            switch sourceArtifact.kind {
            case .html:
                fileName = "source.html"
            case .pdf:
                fileName = "source.pdf"
            }
            try sourceArtifact.data.write(to: directoryURL.appendingPathComponent(fileName), options: .atomic)
            sourceArtifactFileName = fileName
        }

        let entry = HistoryEntry(
            id: id,
            createdAt: createdAt,
            status: request.status,
            rawClipboard: request.rawClipboard,
            sourceURLString: request.sourceURL?.absoluteString,
            routeLabel: Self.routeLabel(for: request.route),
            statusMessage: request.statusMessage,
            directoryPath: directoryURL.path,
            clipboardFileName: clipboardFileName,
            markdownFileName: markdownFileName,
            sourceArtifactFileName: sourceArtifactFileName
        )

        let metadataURL = directoryURL.appendingPathComponent("metadata.json")
        let metadata = try self.encoder.encode(entry)
        try metadata.write(to: metadataURL, options: .atomic)
        return entry
    }

    func loadRecent(limit: Int = 8) async -> [HistoryEntry] {
        guard let root = try? self.historyRootDirectory(),
              let childURLs = try? self.fileManager.contentsOfDirectory(
                  at: root,
                  includingPropertiesForKeys: [.contentModificationDateKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return []
        }

        let entries = childURLs.compactMap { url -> HistoryEntry? in
            let metadataURL = url.appendingPathComponent("metadata.json")
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            return try? self.decoder.decode(HistoryEntry.self, from: data)
        }

        return entries
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    func markdown(for entry: HistoryEntry) async throws -> String {
        guard let url = entry.markdownFileURL else {
            throw HistoryStoreError.markdownUnavailable
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func openHistoryFolder() async throws {
        let root = try self.historyRootDirectory()
        try self.fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        await MainActor.run {
            NSWorkspace.shared.open(root)
        }
    }

    private func makeEntryDirectory(id: UUID, createdAt: Date) throws -> URL {
        let root = try self.historyRootDirectory()
        try self.fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: createdAt)
            .replacingOccurrences(of: ":", with: "-")
        let directoryURL = root.appendingPathComponent("\(timestamp)-\(id.uuidString)", isDirectory: true)
        try self.fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func historyRootDirectory() throws -> URL {
        guard let appSupport = self.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw HistoryStoreError.missingApplicationSupportDirectory
        }
        return appSupport
            .appendingPathComponent("Markyd", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)
    }

    private static func routeLabel(for route: ClipboardURLKind?) -> String? {
        switch route {
        case .webpage:
            "webpage"
        case .pdf:
            "pdf"
        case nil:
            nil
        }
    }
}

enum HistoryStoreError: LocalizedError {
    case missingApplicationSupportDirectory
    case markdownUnavailable

    var errorDescription: String? {
        switch self {
        case .missingApplicationSupportDirectory:
            "Could not locate Application Support for Markyd history."
        case .markdownUnavailable:
            "That history item does not have saved Markdown output."
        }
    }
}
