import Carbon.HIToolbox
import Foundation

final class GlobalHotKeyManager {
    private let settings: HotKeySettings
    private let registrationChanged: @MainActor (String) -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let handler: @Sendable () -> Void

    @MainActor
    init(
        settings: HotKeySettings,
        registrationChanged: @escaping @MainActor (String) -> Void,
        handler: @escaping @Sendable () -> Void
    ) {
        self.settings = settings
        self.registrationChanged = registrationChanged
        self.handler = handler
        self.settings.hotKeyPresetChanged = { [weak self] preset in
            self?.registerHotKey(preset: preset)
        }
        self.installHandler()
        self.registerHotKey(preset: settings.selectedPreset)
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotKeyEvent(event)
                return noErr
            },
            1,
            &eventType,
            pointer,
            &self.eventHandlerRef
        )
    }

    private func registerHotKey(preset: HotKeyPreset) {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x4D4B5944), id: UInt32(1))
        let status = RegisterEventHotKey(
            preset.keyCode,
            preset.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &self.hotKeyRef
        )
        let registrationChanged = self.registrationChanged
        let message = Self.registrationMessage(for: preset, status: status)
        Task { @MainActor in
            registrationChanged(message)
        }
    }

    private func handleHotKeyEvent(_ event: EventRef?) {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr, hotKeyID.id == 1 else { return }
        let handler = self.handler
        DispatchQueue.main.async(execute: handler)
    }

    private static func registrationMessage(for preset: HotKeyPreset, status: OSStatus) -> String {
        if status == noErr {
            return "Shortcut registered: \(preset.title)"
        }

        if status == eventHotKeyExistsErr {
            return "Shortcut conflict: \(preset.title) is already in use."
        }

        return "Shortcut registration failed (\(status)) for \(preset.title)."
    }
}
