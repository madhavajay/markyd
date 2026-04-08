import AppKit
import Carbon.HIToolbox
import Foundation

enum ClipboardPayload {
    case string(String)
    case fileURL(URL)

    var rawValueForHistory: String {
        switch self {
        case let .string(value):
            value
        case let .fileURL(url):
            url.absoluteString
        }
    }
}

@MainActor
final class ClipboardController {
    private let pasteboard: NSPasteboard
    private let accessibilityPermission: AccessibilityPermissionChecking
    private let restoreDelay: Duration

    init(
        pasteboard: NSPasteboard = .general,
        accessibilityPermission: AccessibilityPermissionChecking,
        restoreDelay: Duration = .milliseconds(250)
    ) {
        self.pasteboard = pasteboard
        self.accessibilityPermission = accessibilityPermission
        self.restoreDelay = restoreDelay
    }

    func clipboardString() -> String? {
        self.pasteboard.string(forType: .string)
    }

    func clipboardPayload() -> ClipboardPayload? {
        if let fileURL = self.fileURLFromPasteboard() {
            return .fileURL(fileURL)
        }

        if let string = self.clipboardString(), !string.isEmpty {
            return .string(string)
        }

        return nil
    }

    func copyString(_ string: String) {
        self.pasteboard.clearContents()
        self.pasteboard.setString(string, forType: .string)
    }

    func pasteString(_ string: String) async throws {
        guard self.accessibilityPermission.isTrusted else {
            throw PasteError.accessibilityRequired
        }

        let previous = self.clipboardString()

        self.pasteboard.clearContents()
        self.pasteboard.setString(string, forType: .string)

        try self.sendPasteShortcut()

        let delay = self.restoreDelay
        Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: delay)
            self.pasteboard.clearContents()
            if let previous {
                self.pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private func sendPasteShortcut() throws {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            throw PasteError.eventSourceUnavailable
        }

        let flags: CGEventFlags = .maskCommand
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        else {
            throw PasteError.eventSourceUnavailable
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func fileURLFromPasteboard() -> URL? {
        if let urls = self.pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first
        {
            return first
        }

        if let fileURLString = self.pasteboard.string(forType: .fileURL),
           let fileURL = URL(string: fileURLString)
        {
            return fileURL
        }

        return nil
    }
}

enum PasteError: LocalizedError {
    case accessibilityRequired
    case eventSourceUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Enable Accessibility permission so Markyd can paste into other apps."
        case .eventSourceUnavailable:
            "Unable to synthesize the paste keystroke."
        }
    }
}
