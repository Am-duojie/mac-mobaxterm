import SwiftUI

struct TerminalAreaView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        VStack(spacing: 0) {
            if sessionManager.sessions.isEmpty {
                WelcomeView()
            } else {
                tabBar; Divider()
                if let selectedSession = sessionManager.selectedSession {
                    TerminalSessionView(session: selectedSession)
                        .id(selectedSession.id)
                } else {
                    WelcomeView()
                }
            }
        }
        .background(Color.black)
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(sessionManager.sessions) { session in
                        TabItem(session: session)
                    }
                }
            }
            Button { sessionManager.openLocalSession() } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary).frame(width: 24, height: 24)
            }.buttonStyle(.plain).help("新建终端")
        }.frame(height: 32).background(Color(NSColor.windowBackgroundColor))
    }
}

struct TabItem: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var session: Session
    var isSelected: Bool { sessionManager.selectedSessionId == session.id }
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: session.icon).font(.system(size: 8))
                .foregroundStyle(session.isConnected ? .green : .orange)
            Text(session.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
            Button { sessionManager.closeSession(session.id) } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            }.buttonStyle(.plain).opacity(isSelected ? 1 : 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(isSelected ? Color.black.opacity(0.3) : Color.clear)
        .overlay(alignment: .bottom) { if isSelected { Color.accentColor.frame(height: 2) } }
        .onTapGesture { sessionManager.selectedSessionId = session.id }
        .contextMenu {
            Button("关闭") { sessionManager.closeSession(session.id) }
            Button("关闭其他") { sessionManager.closeOtherSessions(keep: session.id) }
            Button("关闭全部") { sessionManager.closeAllSessions() }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var sessionManager: SessionManager
    var body: some View {
        VStack(spacing: 16) {
            Text("欢迎使用 Mac终端助手").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
            Text("按回车键启动本地终端").font(.system(size: 13)).foregroundColor(.gray)
            HStack(spacing: 12) {
                WelcomeCard(icon: "terminal", title: "本地终端", color: .blue) { sessionManager.openLocalSession() }
                WelcomeCard(icon: "network", title: "SSH连接", color: .green) { sessionManager.showConnectionEditor = true }
            }.padding(.top, 8)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WelcomeCard: View {
    let icon: String, title: String, color: Color, action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 28)).foregroundStyle(color)
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
            }
            .frame(width: 120, height: 100)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}
