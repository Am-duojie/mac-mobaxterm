import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var expandedFolders: Set<UUID> = []
    @State private var searchText: String = ""
    @State private var showNetworkTools: Bool = false
    @State private var selectedTab: SidebarTab = .sessions
    
    enum SidebarTab: String, CaseIterable {
        case sessions = "会话"
        case tools = "工具"
    }
    
    var filteredFolders: [(folder: ConnectionFolder, connections: [Connection])] {
        if searchText.isEmpty {
            return sessionManager.folders.map { (folder: $0, connections: $0.connections) }
        }
        return sessionManager.folders.compactMap { folder in
            let filtered = folder.connections.filter { conn in
                conn.name.localizedCaseInsensitiveContains(searchText) ||
                conn.host.localizedCaseInsensitiveContains(searchText) ||
                conn.username.localizedCaseInsensitiveContains(searchText)
            }
            return filtered.isEmpty ? nil : (folder: folder, connections: filtered)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("查找会话或服务器...", text: $searchText).textFieldStyle(.plain).font(.system(size: 11))
            }.padding(8).background(Color(NSColor.textBackgroundColor))
            
            // 标签切换
            Picker("", selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding(.horizontal, 8).padding(.vertical, 4)
            
            Divider()
            
            if selectedTab == .sessions {
                VStack(spacing: 0) {
                    sessionsList
                    if let session = selectedRemoteFileSession {
                        Divider()
                        RemoteFileBrowserView(session: session)
                            .frame(minHeight: 220, idealHeight: 280, maxHeight: 360)
                    }
                }
            } else {
                toolsList
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button { sessionManager.openNewConnectionEditor() } label: { Image(systemName: "plus.circle") }
                    .buttonStyle(.plain).help("新建会话")
                Button { sessionManager.addFolder() } label: { Image(systemName: "folder.badge.plus") }
                    .buttonStyle(.plain).help("新建文件夹")
                Button { sessionManager.openLocalSession() } label: { Image(systemName: "terminal") }
                    .buttonStyle(.plain).help("本地终端")
                Spacer()
            }.padding(.horizontal, 10).padding(.vertical, 6)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear { expandedFolders = Set(sessionManager.folders.map { $0.id }) }
        .sheet(isPresented: $showNetworkTools) { NetworkToolsView() }
    }

    private var selectedRemoteFileSession: Session? {
        guard let session = sessionManager.selectedSession,
              session.isConnected,
              session.type == .ssh || session.type == .sftp else { return nil }
        return session
    }
    
    // MARK: - 会话列表
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Button { sessionManager.openLocalSession() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "terminal").font(.system(size: 12)).frame(width: 20)
                        Text("启动本地终端").font(.system(size: 12))
                        Spacer()
                    }.padding(.horizontal, 10).padding(.vertical, 6).contentShape(Rectangle())
                }.buttonStyle(.plain)
                
                Divider()
                
                if !sessionManager.sessions.isEmpty {
                    Section {
                        ForEach(sessionManager.sessions) { ActiveSessionRow(session: $0) }
                    } header: {
                        HStack {
                            Text("活跃会话").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(sessionManager.sessions.count)").font(.system(size: 9)).foregroundStyle(.tertiary)
                        }.padding(.horizontal, 10).padding(.vertical, 4)
                    }
                    Divider().padding(.vertical, 4)
                }
                
                ForEach(filteredFolders, id: \.folder.id) { item in
                    FolderSection(folder: item.folder, connections: item.connections,
                                  isExpanded: expandedFolders.contains(item.folder.id),
                                  onToggle: {
                        if expandedFolders.contains(item.folder.id) { expandedFolders.remove(item.folder.id) }
                        else { expandedFolders.insert(item.folder.id) }
                    })
                }
            }.padding(.vertical, 4)
        }
    }
    
    // MARK: - 工具列表
    private var toolsList: some View {
        List {
            Section("网络工具") {
                ToolRow(icon: "wifi", title: "Ping", subtitle: "网络连通性测试") { showNetworkTools = true }
                ToolRow(icon: "point.3.connected.trianglepath.dotted", title: "路由追踪", subtitle: "Traceroute") { showNetworkTools = true }
                ToolRow(icon: "globe", title: "DNS查询", subtitle: "域名解析") { showNetworkTools = true }
                ToolRow(icon: "server.rack", title: "端口扫描", subtitle: "检测开放端口") { showNetworkTools = true }
                ToolRow(icon: "info.circle", title: "Whois", subtitle: "域名信息查询") { showNetworkTools = true }
                ToolRow(icon: "network", title: "网络信息", subtitle: "查看本机网络") { showNetworkTools = true }
            }
            Section("安全工具") {
                ToolRow(icon: "key.fill", title: "SSH密钥生成", subtitle: "生成RSA密钥对") { generateSSHKey() }
                ToolRow(icon: "doc.badge.plus", title: "密钥管理", subtitle: "打开.ssh目录") {
                    NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh"))
                }
            }
        }.listStyle(.sidebar)
    }
    
    private func generateSSHKey() {
        let keyPath = NSHomeDirectory() + "/.ssh/id_rsa_mac终端助手"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        p.arguments = ["-t", "rsa", "-b", "4096", "-f", keyPath, "-N", ""]
        try? p.run()
        p.waitUntilExit()
    }
}

// MARK: - 工具行
struct ToolRow: View {
    let icon: String, title: String, subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.blue).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(.vertical, 6).padding(.horizontal, 4).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

// MARK: - 文件夹
struct FolderSection: View {
    @EnvironmentObject var sessionManager: SessionManager
    let folder: ConnectionFolder, connections: [Connection]
    let isExpanded: Bool, onToggle: () -> Void
    
    var body: some View {
        DisclosureGroup(isExpanded: Binding(get: { isExpanded }, set: { _ in onToggle() })) {
            ForEach(connections) { ConnectionRow(connection: $0).padding(.leading, 4) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: folder.icon).font(.system(size: 10)).foregroundStyle(.secondary)
                Text(folder.name).font(.system(size: 11, weight: .medium))
                Spacer()
                Text("\(connections.count)").font(.system(size: 9)).foregroundStyle(.tertiary)
            }.contentShape(Rectangle()).contextMenu {
                Button("在此新建会话") { sessionManager.openNewConnectionEditor(folderId: folder.id) }
                Divider()
                Button("删除文件夹", role: .destructive) { sessionManager.deleteFolder(folder.id) }
            }
        }.padding(.horizontal, 6)
    }
}

// MARK: - 连接行
struct ConnectionRow: View {
    @EnvironmentObject var sessionManager: SessionManager
    let connection: Connection
    @State private var isRenaming: Bool = false
    @State private var draftName: String = ""
    
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(colorForTag(connection.colorTag)).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 0) {
                if isRenaming {
                    TextField("会话名称", text: $draftName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .onSubmit { commitRename() }
                } else {
                    Text(connection.name.isEmpty ? "\(connection.host) (\(connection.username))" : connection.name)
                        .font(.system(size: 11)).lineLimit(1)
                }
                if !connection.host.isEmpty { Text(connection.host).font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Spacer()
            if connection.isFavorite { Image(systemName: "star.fill").font(.system(size: 7)).foregroundStyle(.yellow) }
            Text(connection.type.rawValue.uppercased())
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6).padding(.vertical, 3).contentShape(Rectangle())
        .background(RoundedRectangle(cornerRadius: 3).fill(sessionManager.selectedConnectionId == connection.id ? Color.accentColor.opacity(0.15) : Color.clear))
        .onTapGesture { sessionManager.selectedConnectionId = connection.id }
        .onTapGesture(count: 2) { sessionManager.openConnection(connection) }
        .contextMenu {
            Button("执行") { sessionManager.openConnection(connection) }
            Button("连接为...") { sessionManager.openEditConnectionEditor(connection) }
            Button("Ping 主机") { sessionManager.showConnectionEditor = false }
            Divider()
            Button("重命名会话") { beginRename() }
            Button("编辑...") { sessionManager.openEditConnectionEditor(connection) }
            Button("复制会话") { sessionManager.duplicateConnection(connection) }
            Divider()
            Button("保存会话到文件...") { exportConnection() }
            Button("复制会话设置") { copyConnectionSummary() }
            Divider()
            Button("删除", role: .destructive) { sessionManager.deleteConnection(connection) }
        }
    }
    
    private func colorForTag(_ tag: String) -> Color {
        switch tag {
        case "red": return .red; case "orange": return .orange; case "yellow": return .yellow
        case "green": return .green; case "blue": return .blue; case "purple": return .purple
        case "pink": return .pink; default: return .gray
        }
    }

    private func beginRename() {
        draftName = connection.name.isEmpty ? connection.displayName : connection.name
        isRenaming = true
    }

    private func commitRename() {
        var renamed = connection
        renamed.name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        sessionManager.updateConnection(renamed)
        isRenaming = false
    }

    private func exportConnection() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(connection.displayName).json"
        if panel.runModal() == .OK,
           let url = panel.url,
           let data = try? JSONEncoder().encode(connection) {
            try? data.write(to: url)
        }
    }

    private func copyConnectionSummary() {
        let text = "\(connection.type.rawValue.uppercased()) \(connection.displayName) \(connection.host):\(connection.port)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - 活跃会话
struct ActiveSessionRow: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var session: Session
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: session.icon).font(.system(size: 10))
                .foregroundStyle(session.isConnected ? .green : .orange).frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(session.title).font(.system(size: 10)).lineLimit(1)
                if let conn = session.connection {
                    Text("\(conn.username)@\(conn.host)").font(.system(size: 8)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if sessionManager.selectedSessionId == session.id { Circle().fill(Color.accentColor).frame(width: 5, height: 5) }
        }
        .padding(.horizontal, 8).padding(.vertical, 3).contentShape(Rectangle())
        .onTapGesture { sessionManager.selectedSessionId = session.id }
    }
}
