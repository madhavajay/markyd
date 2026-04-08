import Carbon.HIToolbox
import SwiftUI

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case commandShiftM
    case commandControlOptionV
    case commandControlOptionM
    case commandControlShiftV
    case commandOptionShiftV

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .commandShiftM:
            "Command + Shift + M"
        case .commandControlOptionV:
            "Command + Control + Option + V"
        case .commandControlOptionM:
            "Command + Control + Option + M"
        case .commandControlShiftV:
            "Command + Control + Shift + V"
        case .commandOptionShiftV:
            "Command + Option + Shift + V"
        }
    }

    var isRecommended: Bool {
        self == .commandShiftM
    }

    var keyCode: UInt32 {
        switch self {
        case .commandShiftM:
            UInt32(kVK_ANSI_M)
        case .commandControlOptionV, .commandControlShiftV, .commandOptionShiftV:
            UInt32(kVK_ANSI_V)
        case .commandControlOptionM:
            UInt32(kVK_ANSI_M)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .commandShiftM:
            UInt32(cmdKey | shiftKey)
        case .commandControlOptionV, .commandControlOptionM:
            UInt32(cmdKey | controlKey | optionKey)
        case .commandControlShiftV:
            UInt32(cmdKey | controlKey | shiftKey)
        case .commandOptionShiftV:
            UInt32(cmdKey | optionKey | shiftKey)
        }
    }
}

@MainActor
final class HotKeySettings: ObservableObject {
    @AppStorage("hotKeyPreset") private var hotKeyPresetRawValue: String = HotKeyPreset.commandShiftM.rawValue {
        didSet {
            self.hotKeyPresetChanged?(self.selectedPreset)
            self.objectWillChange.send()
        }
    }

    var hotKeyPresetChanged: ((HotKeyPreset) -> Void)?

    var selectedPreset: HotKeyPreset {
        get { HotKeyPreset(rawValue: self.hotKeyPresetRawValue) ?? .commandShiftM }
        set { self.hotKeyPresetRawValue = newValue.rawValue }
    }
}
