import Foundation
import MarkydCore

enum MenuBarFeedbackState {
    case idle
    case processing
    case success
    case failure
}

@MainActor
final class MarkdownPasteCoordinator: ObservableObject {
    @Published private(set) var lastStatus: String = "Ready"
    @Published private(set) var isProcessing = false
    @Published private(set) var recentHistory: [HistoryEntry] = []
    @Published private(set) var hotKeyRegistrationStatus: String = "Shortcut registration pending."
    @Published private(set) var lastHotKeyEventStatus: String = "Shortcut not triggered yet."
    @Published private(set) var hotKeyTriggerCount: Int = 0
    @Published private(set) var menuBarFeedbackState: MenuBarFeedbackState = .idle
    @Published private(set) var menuBarPulseToken: Int = 0

    private let accessibilityPermission: AccessibilityPermissionManager
    private let historySettings: HistorySettings
    private let clipboard: ClipboardController
    private let conversionService: MarkdownConversionService
    private let historyStore: HistoryStore
    private var feedbackResetTask: Task<Void, Never>?
    private var lastGeneratedMarkdown: String?

    init(accessibilityPermission: AccessibilityPermissionManager, historySettings: HistorySettings) {
        self.accessibilityPermission = accessibilityPermission
        self.historySettings = historySettings
        self.clipboard = ClipboardController(accessibilityPermission: accessibilityPermission)
        self.conversionService = MarkdownConversionService()
        self.historyStore = HistoryStore()
        Task {
            await self.reloadHistory()
        }
    }

    func triggerPaste() {
        guard !self.isProcessing else { return }

        Task {
            await self.processPasteRequest()
        }
    }

    func handleHotKeyTrigger() {
        self.hotKeyTriggerCount += 1
        self.lastHotKeyEventStatus =
            "Shortcut received at \(Date.now.formatted(date: .omitted, time: .standard)) (#\(self.hotKeyTriggerCount))."
        self.triggerMenuBarFeedback(.processing, autoReset: false)

        if self.isProcessing {
            self.lastStatus = "Shortcut received while a conversion was already running."
            self.triggerMenuBarFeedback(.failure)
            return
        }

        self.lastStatus = "Shortcut received. Checking clipboard…"
        self.triggerPaste()
    }

    func setHotKeyRegistrationStatus(_ status: String) {
        self.hotKeyRegistrationStatus = status
    }

    func requestAccessibility() {
        self.accessibilityPermission.requestPermissionPrompt()
    }

    func pasteHistoryEntry(_ entry: HistoryEntry) {
        guard !self.isProcessing else { return }
        Task {
            do {
                let markdown = try await self.historyStore.markdown(for: entry)
                try await self.clipboard.pasteString(markdown)
                await MainActor.run {
                    self.lastStatus = "Pasted saved Markdown from history."
                }
            } catch {
                await MainActor.run {
                    self.lastStatus = error.localizedDescription
                }
            }
        }
    }

    func openHistoryFolder() {
        Task {
            do {
                try await self.historyStore.openHistoryFolder()
            } catch {
                await MainActor.run {
                    self.lastStatus = error.localizedDescription
                }
            }
        }
    }

    private func processPasteRequest() async {
        guard let payload = self.clipboard.clipboardPayload() else {
            self.lastStatus = "Clipboard is empty."
            self.triggerMenuBarFeedback(.failure)
            return
        }

        if case let .string(rawValue) = payload, rawValue == self.lastGeneratedMarkdown {
            self.lastStatus = "Clipboard already contains the latest Markdown."
            self.triggerMenuBarFeedback(.success)
            return
        }

        self.isProcessing = true
        self.lastStatus = self.processingStatusMessage(for: payload)

        defer {
            self.isProcessing = false
        }

        do {
            let result = try await self.convert(payload)
            let status: String
            if self.shouldWriteMarkdownFile(for: result) {
                let outputURL = try self.writeMarkdownFile(result.markdown, for: result.sourceURL)
                status = "Saved Markdown file to \(outputURL.lastPathComponent)"
            } else if self.accessibilityPermission.isTrusted {
                try await self.clipboard.pasteString(result.markdown)
                status = self.statusMessage(for: result.route, url: result.sourceURL)
            } else {
                self.clipboard.copyString(result.markdown)
                status = self.clipboardOnlyStatusMessage(for: result.route, url: result.sourceURL)
            }
            self.lastGeneratedMarkdown = result.markdown
            self.lastStatus = status
            self.triggerMenuBarFeedback(.success)
            await self.archiveAttempt(
                rawClipboard: payload.rawValueForHistory,
                result: result,
                status: .succeeded,
                statusMessage: status
            )
        } catch {
            let message = error.localizedDescription
            self.lastStatus = message
            self.triggerMenuBarFeedback(.failure)
            await self.archiveAttempt(
                rawClipboard: payload.rawValueForHistory,
                result: nil,
                status: .failed,
                statusMessage: message
            )
        }
    }

    private func archiveAttempt(
        rawClipboard: String,
        result: MarkdownConversionResult?,
        status: HistoryAttemptStatus,
        statusMessage: String
    ) async {
        guard self.historySettings.isHistoryEnabled else { return }

        do {
            _ = try await self.historyStore.save(
                HistoryArchiveRequest(
                    rawClipboard: rawClipboard,
                    sourceURL: result?.sourceURL,
                    route: result?.route,
                    status: status,
                    statusMessage: statusMessage,
                    markdown: result?.markdown,
                    sourceArtifact: result?.sourceArtifact
                )
            )
            await self.reloadHistory()
        } catch {
            self.lastStatus = "Saved conversion failed: \(error.localizedDescription)"
        }
    }

    private func reloadHistory() async {
        self.recentHistory = await self.historyStore.loadRecent()
    }

    private func statusMessage(for route: ClipboardURLKind, url: URL) -> String {
        switch route {
        case .webpage:
            "Pasted webpage Markdown from \(url.host(percentEncoded: false) ?? url.absoluteString)"
        case .pdf:
            "Pasted PDF Markdown from \(url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent)"
        }
    }

    private func clipboardOnlyStatusMessage(for route: ClipboardURLKind, url: URL) -> String {
        switch route {
        case .webpage:
            "Converted webpage from \(url.host(percentEncoded: false) ?? url.absoluteString) and copied Markdown to the clipboard. Accessibility is still needed for auto-paste."
        case .pdf:
            "Converted PDF from \(url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent) and copied Markdown to the clipboard. Accessibility is still needed for auto-paste."
        }
    }

    private func triggerMenuBarFeedback(_ state: MenuBarFeedbackState, autoReset: Bool = true) {
        self.feedbackResetTask?.cancel()
        self.menuBarFeedbackState = state
        self.menuBarPulseToken += 1

        guard autoReset, state != .idle else { return }

        self.feedbackResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard let self else { return }
            self.menuBarFeedbackState = .idle
        }
    }

    private func convert(_ payload: ClipboardPayload) async throws -> MarkdownConversionResult {
        switch payload {
        case let .string(rawValue):
            try await self.conversionService.convertClipboardValue(rawValue)
        case let .fileURL(url):
            try await self.conversionService.convertClipboardURL(url)
        }
    }

    private func shouldWriteMarkdownFile(for result: MarkdownConversionResult) -> Bool {
        result.sourceURL.isFileURL && result.route == .pdf(result.sourceURL)
    }

    private func writeMarkdownFile(_ markdown: String, for sourceURL: URL) throws -> URL {
        let outputURL = MarkdownFileNaming.outputURL(for: sourceURL)
        try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
        return outputURL
    }

    private func processingStatusMessage(for payload: ClipboardPayload) -> String {
        switch payload {
        case .string:
            "Converting clipboard URL…"
        case let .fileURL(url):
            "Converting \(url.lastPathComponent)…"
        }
    }
}
