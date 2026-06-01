import Foundation
import SwiftUI

class SessionManager: ObservableObject {
    @Published var folders: [ConnectionFolder] = []
    @Published var selectedConnectionId: UUID?
    @Published var sessions: [Session] = []
    @Published var selectedSessionId: UUID?
    @Published var showNewConnection: Bool = false
    @Published var showConnectionEditor: Bool = false
    @Published var editingConnection: Connection?
    @Published var editingFolderId: UUID?
    @Published var showSettings: Bool = false
    
    private let storageKey = "MacMobaXterm.Folders"
    
    var selectedSession: Session? { sessions.first { $0.id == selectedSessionId } }
    var allConnections: [Connection] { folders.flatMap { $0.connections } }
    
    init() {
        AppDefaults.register()
        loadFolders()
        if folders.isEmpty {
            folders = [
                ConnectionFolder(name: "收藏夹", icon: "star"),
                ConnectionFolder(name: "开发环境", icon: "hammer"),
                ConnectionFolder(name: "生产环境", icon: "server.rack"),
            ]
        }
    }
    
    // MARK: - 连接CRUD
    func addConnection(_ c: Connection, to folderId: UUID?) {
        var sanitized = c
        storeCredentials(for: &sanitized)
        if let folderId, let i = folders.firstIndex(where: { $0.id == folderId }) {
            folders[i].connections.append(sanitized)
        } else { folders[0].connections.append(sanitized) }
        saveFolders()
    }
    
    func updateConnection(_ c: Connection) {
        var sanitized = c
        storeCredentials(for: &sanitized)
        for (fi, f) in folders.enumerated() {
            if let ci = f.connections.firstIndex(where: { $0.id == sanitized.id }) {
                folders[fi].connections[ci] = sanitized; break
            }
        }
        saveFolders()
    }
    
    func deleteConnection(_ id: UUID) {
        for (fi, _) in folders.enumerated() {
            folders[fi].connections.removeAll {
                if $0.id == id { CredentialStore.delete(id: $0.credentialId) }
                return $0.id == id
            }
        }
        saveFolders()
    }
    
    func deleteConnection(_ c: Connection) { deleteConnection(c.id) }
    func addFolder(name: String = "新建文件夹") { folders.append(ConnectionFolder(name: name)); saveFolders() }
    func deleteFolder(_ id: UUID) { folders.removeAll { $0.id == id }; saveFolders() }
    
    // MARK: - 会话管理
    func openConnection(_ conn: Connection) {
        switch conn.type {
        case .ssh:
            openSSH(conn)
        case .sftp:
            openSFTP(conn)
        case .telnet:
            openTelnet(conn)
        case .rdp:
            openRDP(conn)
        case .ftp:
            openFTP(conn)
        case .vnc:
            openVNC(conn)
        case .serial:
            openSerial(conn, port: conn.serialPort, baud: conn.serialBaud)
        case .local:
            openLocalSession()
        }
    }
    
    func openSSH(_ conn: Connection) {
        let s = Session(type: .ssh, connection: conn)
        sessions.append(s); selectedSessionId = s.id
        s.isConnected = true; s.statusMessage = "已连接到 \(conn.host)"
    }
    
    func openLocalSession() {
        let s = Session(type: .local)
        sessions.append(s); selectedSessionId = s.id
        s.isConnected = true; s.statusMessage = "本地Shell"
    }
    
    func openSFTP(_ conn: Connection) {
        let s = Session(type: .sftp, connection: conn)
        sessions.append(s); selectedSessionId = s.id
        s.isConnected = true; s.statusMessage = "SFTP: \(conn.host)"
    }
    
    func openTelnet(_ conn: Connection) {
        let s = Session(type: .telnet, connection: conn)
        sessions.append(s); selectedSessionId = s.id
        s.isConnected = true; s.statusMessage = "Telnet: \(conn.host):\(conn.port)"
    }
    
    func openRDP(_ conn: Connection) {
        let s = Session(type: .rdp, connection: conn)
        sessions.append(s); selectedSessionId = s.id
        
        // 生成 .rdp 文件并用 Windows App 打开
        let rdpContent = """
full address:s:\(conn.host):\(conn.port)
username:s:\(conn.username)
prompt for credentials:i:1
screen mode id:i:2
desktopwidth:i:1920
desktopheight:i:1080
session bpp:i:32
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
"""
        
        let tmpPath = NSTemporaryDirectory() + "macmobaxterm_rdp.rdp"
        do {
            try rdpContent.write(toFile: tmpPath, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(URL(fileURLWithPath: tmpPath))
            s.isConnected = true; s.statusMessage = "已连接: \(conn.host)"
        } catch {
            s.statusMessage = "RDP文件创建失败: \(error.localizedDescription)"
        }
    }
    func openVNC(_ conn: Connection) {
        let s = Session(type: .vnc, connection: conn)
        sessions.append(s); selectedSessionId = s.id
        if let url = URL(string: "vnc://" + conn.host + ":" + String(conn.port)) {
            NSWorkspace.shared.open(url)
            s.isConnected = true; s.statusMessage = "已启动屏幕共享"
        } else {
            s.statusMessage = "VNC地址无效"
        }
    }
    func openFTP(_ conn: Connection) {
        let s = Session(type: .ftp, connection: conn)
        sessions.append(s); selectedSessionId = s.id
        s.isConnected = true; s.statusMessage = "FTP: \(conn.host):\(conn.port)"
    }
    
    func openSerial(_ conn: Connection, port: String, baud: Int) {
        var serialConnection = conn
        serialConnection.type = .serial
        serialConnection.serialPort = port
        serialConnection.serialBaud = baud
        serialConnection.host = port
        serialConnection.port = baud
        let s = Session(type: .serial, connection: serialConnection)
        sessions.append(s); selectedSessionId = s.id
        s.isConnected = true; s.statusMessage = "串口: \(port) @ \(baud)"
    }
    
    func duplicateConnection(_ conn: Connection, to folderId: UUID? = nil) {
        var dup = conn
        dup.id = UUID()
        dup.name = conn.name.isEmpty ? "\(conn.displayName) (副本)" : "\(conn.name) (副本)"
        addConnection(dup, to: folderId)
    }
    
    func closeSession(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionId == id { selectedSessionId = sessions.last?.id }
    }
    
    func closeOtherSessions(keep id: UUID) {
        sessions.removeAll { $0.id != id }; selectedSessionId = id
    }
    
    func closeAllSessions() { sessions.removeAll(); selectedSessionId = nil }
    
    func openNewConnectionEditor(folderId: UUID? = nil) {
        editingConnection = nil; editingFolderId = folderId; showConnectionEditor = true
    }
    
    func openEditConnectionEditor(_ c: Connection, folderId: UUID? = nil) {
        editingConnection = hydrateCredentials(for: c); editingFolderId = folderId; showConnectionEditor = true
    }
    
    func importFolders(_ importedFolders: [ConnectionFolder]) {
        folders.append(contentsOf: importedFolders)
        saveFolders()
    }
    
    func moveConnection(_ id: UUID, to folderId: UUID) {
        guard let targetIndex = folders.firstIndex(where: { $0.id == folderId }) else { return }
        var moving: Connection?
        for index in folders.indices {
            if let connectionIndex = folders[index].connections.firstIndex(where: { $0.id == id }) {
                moving = folders[index].connections.remove(at: connectionIndex)
                break
            }
        }
        if let moving {
            folders[targetIndex].connections.append(moving)
            saveFolders()
        }
    }
    
    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) { UserDefaults.standard.set(data, forKey: storageKey) }
    }
    
    private func loadFolders() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ConnectionFolder].self, from: data) {
            folders = decoded
            migratePlaintextCredentials()
        }
    }
    
    private func storeCredentials(for connection: inout Connection) {
        CredentialStore.save(
            ConnectionCredential(password: connection.password, passphrase: connection.passphrase),
            id: connection.credentialId
        )
        connection.password = ""
        connection.passphrase = ""
    }
    
    private func hydrateCredentials(for connection: Connection) -> Connection {
        var c = connection
        if let credential = CredentialStore.load(id: c.credentialId) {
            c.password = credential.password
            c.passphrase = credential.passphrase
        }
        return c
    }
    
    private func migratePlaintextCredentials() {
        var changed = false
        for folderIndex in folders.indices {
            for connectionIndex in folders[folderIndex].connections.indices {
                var connection = folders[folderIndex].connections[connectionIndex]
                if !connection.password.isEmpty || !connection.passphrase.isEmpty {
                    storeCredentials(for: &connection)
                    folders[folderIndex].connections[connectionIndex] = connection
                    changed = true
                }
            }
        }
        if changed { saveFolders() }
    }
}
