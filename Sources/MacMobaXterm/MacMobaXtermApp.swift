import SwiftUI

@main
struct MacMobaXtermApp: App {
    @StateObject private var sessionManager = SessionManager()
    
    init() {
        AppDefaults.register()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建连接...") { sessionManager.showConnectionEditor = true }
                    .keyboardShortcut("n", modifiers: .command)
                Button("新建本地终端") { sessionManager.openLocalSession() }
                    .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}
