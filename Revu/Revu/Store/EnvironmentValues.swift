import SwiftUI

private struct StorageKey: EnvironmentKey {
    static var defaultValue: Storage = {
        // Fallback for previews/tests when not injected at the app root
        DataController.shared.storage
    }()
}

extension EnvironmentValues {
    var storage: Storage {
        get { self[StorageKey.self] }
        set { self[StorageKey.self] = newValue }
    }
}
