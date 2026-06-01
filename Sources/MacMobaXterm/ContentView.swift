import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var showSFTP: Bool = false
    @State private var showNetworkTools: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            MenuBarView(showSFTP: $showSFTP, showNetworkTools: $showNetworkTools, showSettings: $sessionManager.showSettings)
            Divider()
            HSplitView {
                SidebarView().frame(minWidth: 200, idealWidth: 250, maxWidth: 350)
                VStack(spacing: 0) {
                    TerminalAreaView().frame(maxHeight: .infinity)
                    if showSFTP { Divider(); SFTPPanelView(showSFTP: $showSFTP).frame(height: 220) }
                }
            }
            StatusBarView()
        }
        .sheet(isPresented: $sessionManager.showConnectionEditor) { SessionEditorView() }
        .sheet(isPresented: $showNetworkTools) { NetworkToolsView() }
        .sheet(isPresented: $sessionManager.showSettings) { SettingsView() }
    }
}
