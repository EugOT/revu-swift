import SwiftUI

@main
struct RevuApp: App {
    private let dataController = DataController.shared
    @StateObject private var workspacePreferences = WorkspacePreferences()
    @StateObject private var commandCenter = WorkspaceCommandCenter()

    init() {
        NotificationService.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.storage, dataController.storage)
                .environmentObject(dataController.events)
                .environmentObject(workspacePreferences)
                .environmentObject(commandCenter)
        }
        .defaultSize(width: 1200, height: 720)
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Quick Find…") {
                    commandCenter.openQuickFind()
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
            SidebarCommands()
            CommandGroup(after: .sidebar) {
                Toggle("Show Tags Column", isOn: $workspacePreferences.showTagColumn)
                    .keyboardShortcut("t", modifiers: [.command, .option])
            }
        }
    }
}
