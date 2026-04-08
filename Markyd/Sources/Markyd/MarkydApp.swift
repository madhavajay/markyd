import AppKit
import SwiftUI

@main
@MainActor
struct MarkydApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var permissions = AccessibilityPermissionManager()
    @StateObject private var hotKeySettings: HotKeySettings
    @StateObject private var historySettings: HistorySettings
    @StateObject private var coordinator: MarkdownPasteCoordinator
    private let hotKeyManager: GlobalHotKeyManager

    init() {
        let permissions = AccessibilityPermissionManager()
        let hotKeySettings = HotKeySettings()
        let historySettings = HistorySettings()
        let coordinator = MarkdownPasteCoordinator(
            accessibilityPermission: permissions,
            historySettings: historySettings
        )
        _permissions = StateObject(wrappedValue: permissions)
        _hotKeySettings = StateObject(wrappedValue: hotKeySettings)
        _historySettings = StateObject(wrappedValue: historySettings)
        _coordinator = StateObject(wrappedValue: coordinator)
        self.hotKeyManager = GlobalHotKeyManager(
            settings: hotKeySettings,
            registrationChanged: { status in
                coordinator.setHotKeyRegistrationStatus(status)
            }
        ) {
            Task { @MainActor in
                coordinator.handleHotKeyTrigger()
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                coordinator: self.coordinator,
                permissions: self.permissions,
                hotKeySettings: self.hotKeySettings,
                historySettings: self.historySettings
            )
        } label: {
            MenuBarStatusView(coordinator: self.coordinator)
        }
    }
}

private struct MenuBarStatusView: View {
    @ObservedObject var coordinator: MarkdownPasteCoordinator

    var body: some View {
        Image(systemName: "doc.richtext")
            .symbolRenderingMode(.palette)
            .foregroundStyle(self.primaryColor, self.secondaryColor)
            .symbolEffect(.pulse.byLayer, value: self.coordinator.menuBarPulseToken)
            .help(self.helpText)
    }

    private var primaryColor: Color {
        switch self.coordinator.menuBarFeedbackState {
        case .idle:
            .primary
        case .processing:
            .yellow
        case .success:
            .green
        case .failure:
            .red
        }
    }

    private var secondaryColor: Color {
        switch self.coordinator.menuBarFeedbackState {
        case .idle:
            .secondary
        case .processing:
            Color.yellow.opacity(0.5)
        case .success:
            Color.green.opacity(0.45)
        case .failure:
            Color.red.opacity(0.45)
        }
    }

    private var helpText: String {
        switch self.coordinator.menuBarFeedbackState {
        case .idle:
            "Paste source or URL"
        case .processing:
            "Markyd is converting the current clipboard item."
        case .success:
            "Markyd converted successfully."
        case .failure:
            "Markyd hit an error. Open the menu for details."
        }
    }
}
