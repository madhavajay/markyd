import AppKit
import ApplicationServices
import Foundation

@MainActor
protocol AccessibilityPermissionChecking: AnyObject {
    var isTrusted: Bool { get }
}

@MainActor
final class AccessibilityPermissionManager: ObservableObject, AccessibilityPermissionChecking {
    @Published private(set) var isTrusted: Bool

    private var pollTask: Task<Void, Never>?

    init() {
        self.isTrusted = AXIsProcessTrusted()
        self.pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let trusted = AXIsProcessTrusted()
                if trusted != self.isTrusted {
                    self.isTrusted = trusted
                }
            }
        }
    }

    deinit {
        self.pollTask?.cancel()
    }

    func requestPermissionPrompt() {
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options)
        self.openSystemSettings()
    }

    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
