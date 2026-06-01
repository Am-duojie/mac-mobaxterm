import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    
    var body: some View {
        HStack(spacing: 16) {
            if let session = sessionManager.selectedSession {
                HStack(spacing: 6) {
                    Circle().fill(session.isConnected ? .green : .orange).frame(width: 6, height: 6)
                    Text(session.title).font(.system(size: 12))
                    if let conn = session.connection {
                        Text("• \(conn.host)").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("无活动会话").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text("Mac终端助手 v1.0").font(.system(size: 11)).foregroundStyle(.tertiary)
            
            Spacer()
            
            HStack(spacing: 14) {
                Label("\(sessionManager.allConnections.count)", systemImage: "network")
                Label("\(sessionManager.sessions.count)", systemImage: "rectangle.stack")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
