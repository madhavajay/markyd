import SwiftUI
import MarkydCore

struct MenuContentView: View {
    @ObservedObject var coordinator: MarkdownPasteCoordinator
    @ObservedObject var permissions: AccessibilityPermissionManager
    @ObservedObject var hotKeySettings: HotKeySettings
    @ObservedObject var historySettings: HistorySettings

    private var hotKeySelection: Binding<HotKeyPreset> {
        Binding(
            get: { self.hotKeySettings.selectedPreset },
            set: { self.hotKeySettings.selectedPreset = $0 }
        )
    }

    private var historyEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.historySettings.isHistoryEnabled },
            set: { self.historySettings.isHistoryEnabled = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Paste source or URL")
                .font(.headline)

            Text("Hotkey: \(self.hotKeySettings.selectedPreset.title)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(self.coordinator.hotKeyRegistrationStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(self.coordinator.lastHotKeyEventStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(self.coordinator.lastStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Button(self.coordinator.isProcessing ? "Converting…" : "Paste Markdown Now") {
                self.coordinator.triggerPaste()
            }
            .disabled(self.coordinator.isProcessing)

            Toggle("Save conversion history", isOn: self.historyEnabledBinding)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Shortcut Presets")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Shortcut Presets", selection: self.hotKeySelection) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.title + (preset.isRecommended ? " (Recommended)" : ""))
                            .tag(preset)
                    }
                }
                .pickerStyle(.menu)

                if self.hotKeySettings.selectedPreset != .commandShiftM {
                    Button("Switch To Command + Shift + M") {
                        self.hotKeySettings.selectedPreset = .commandShiftM
                    }
                    .font(.caption)
                }

                Text("Markyd cannot reliably inspect every app-specific shortcut, so use one of these presets if a conflict appears.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Recent History")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Open Folder") {
                        self.coordinator.openHistoryFolder()
                    }
                    .font(.caption)
                }

                if self.coordinator.recentHistory.isEmpty {
                    Text("No saved conversions yet.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(self.coordinator.recentHistory.prefix(5)) { entry in
                        Button {
                            self.coordinator.pasteHistoryEntry(entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(self.historyTitle(for: entry))
                                    .lineLimit(1)
                                Text(self.historySubtitle(for: entry))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(entry.markdownFileName == nil)
                    }
                }
            }

            if !self.permissions.isTrusted {
                Divider()

                Button("Enable Accessibility Permission") {
                    self.coordinator.requestAccessibility()
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private func historyTitle(for entry: HistoryEntry) -> String {
        if let sourceURL = entry.sourceURL {
            if let host = sourceURL.host(percentEncoded: false) {
                return host
            }
            return sourceURL.lastPathComponent.isEmpty ? sourceURL.absoluteString : sourceURL.lastPathComponent
        }
        return ClipboardSummary.summarize(entry.rawClipboard)
    }

    private func historySubtitle(for entry: HistoryEntry) -> String {
        let status = entry.status == .succeeded ? "Saved" : "Failed"
        let route = entry.routeLabel.map { " \($0)" } ?? ""
        return "\(status)\(route) • \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
