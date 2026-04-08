import SwiftUI

@MainActor
final class HistorySettings: ObservableObject {
    @AppStorage("historyEnabled") private var historyEnabledStorage: Bool = true {
        didSet {
            self.objectWillChange.send()
        }
    }

    var isHistoryEnabled: Bool {
        get { self.historyEnabledStorage }
        set { self.historyEnabledStorage = newValue }
    }
}
