import SwiftUI

struct SFTPPanelView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var showSFTP: Bool
    @State private var localPath: String = NSHomeDirectory()
    @State private var localFiles: [FileItem] = []
    @State private var selectedLocal: FileItem?
    @State private var remotePath: String = "~"
    @State private var remoteFiles: [FileItem] = []
    @State private var selectedRemote: FileItem?
    @State private var remoteStatus: String = "请先建立 SSH/SFTP 连接"
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Label("SFTP 浏览器", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Button { loadFiles(); loadRemoteFiles() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain).help("刷新")
                Button { showSFTP = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("关闭")
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            HStack(spacing: 0) {
                // 本地文件
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "laptopcomputer").font(.caption).foregroundStyle(.secondary)
                        Text("本地").font(.system(size: 11, weight: .medium))
                        TextField("路径", text: $localPath).textFieldStyle(.plain).font(.system(size: 11))
                            .onSubmit { loadFiles() }
                        Button { loadFiles() } label: {
                            Image(systemName: "arrow.right.circle").font(.caption)
                        }.buttonStyle(.plain)
                    }.padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    
                    List(localFiles, selection: $selectedLocal) { file in
                        HStack(spacing: 6) {
                            Image(systemName: file.icon).font(.caption)
                                .foregroundStyle(file.isDirectory ? .blue : .secondary).frame(width: 16)
                            Text(file.name).font(.system(size: 11))
                            Spacer()
                            Text(file.sizeText).font(.system(size: 10)).foregroundStyle(.tertiary)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.vertical, 1)
                        .onTapGesture(count: 2) {
                            if file.isDirectory {
                                localPath = file.path
                                loadFiles()
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                
                Divider()
                
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "server.rack").font(.caption).foregroundStyle(.secondary)
                        Text("远程").font(.system(size: 11, weight: .medium))
                        TextField("路径", text: $remotePath).textFieldStyle(.plain).font(.system(size: 11))
                            .onSubmit { loadRemoteFiles() }
                        Button { loadRemoteFiles() } label: {
                            Image(systemName: "arrow.right.circle").font(.caption)
                        }.buttonStyle(.plain)
                    }.padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    
                    if remoteFiles.isEmpty {
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "server.rack").font(.system(size: 24)).foregroundStyle(.secondary)
                            Text(remoteStatus).font(.caption).foregroundStyle(.tertiary)
                            Spacer()
                        }.frame(maxWidth: .infinity)
                    } else {
                        List(remoteFiles, selection: $selectedRemote) { file in
                            HStack(spacing: 6) {
                                Image(systemName: file.icon).font(.caption)
                                    .foregroundStyle(file.isDirectory ? .blue : .secondary).frame(width: 16)
                                Text(file.name).font(.system(size: 11))
                                Spacer()
                                Text(file.sizeText).font(.system(size: 10)).foregroundStyle(.tertiary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .padding(.vertical, 1)
                            .onTapGesture(count: 2) {
                                if file.isDirectory {
                                    remotePath = file.path
                                    loadRemoteFiles()
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            loadFiles()
            if let remote = sessionManager.selectedSession?.connection?.remotePath, !remote.isEmpty {
                remotePath = remote
            }
            loadRemoteFiles()
        }
    }
    
    private func loadFiles() {
        localFiles = []
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: localPath) else { return }
        for item in items.sorted() {
            let fullPath = (localPath as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            fm.fileExists(atPath: fullPath, isDirectory: &isDir)
            let attrs = try? fm.attributesOfItem(atPath: fullPath)
            localFiles.append(FileItem(name: item, path: fullPath, isDirectory: isDir.boolValue, size: attrs?[.size] as? Int64 ?? 0))
        }
        localFiles.sort { ($0.isDirectory && !$1.isDirectory) || ($0.isDirectory == $1.isDirectory && $0.name < $1.name) }
    }
    
    private func loadRemoteFiles() {
        guard let session = sessionManager.selectedSession,
              (session.type == .ssh || session.type == .sftp),
              let conn = session.connection else {
            remoteFiles = []
            remoteStatus = "请先建立 SSH/SFTP 连接"
            return
        }
        
        remoteStatus = "正在读取远程目录..."
        let path = remotePath
        DispatchQueue.global().async {
            var args = SSHRuntimeOptions.baseArgs(port: conn.port)
            if (conn.authMethod == .key || conn.authMethod == .keyWithPassphrase), !conn.privateKeyPath.isEmpty {
                args += ["-i", conn.privateKeyPath]
            }
            let target = conn.username.isEmpty ? conn.host : "\(conn.username)@\(conn.host)"
            args += [target, "ls -la \(path.shellQuoted)"]
            let result = CommandRunner.run("/usr/bin/ssh", args, timeout: 12)
            let files = result.succeeded ? parseRemoteListing(result.output, basePath: path) : []
            DispatchQueue.main.async {
                remoteFiles = files
                remoteStatus = result.succeeded ? "目录为空" : result.output
            }
        }
    }
    
    private func parseRemoteListing(_ output: String, basePath: String) -> [FileItem] {
        output
            .split(separator: "\n")
            .compactMap { line -> FileItem? in
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 9 else { return nil }
                let permissions = String(parts[0])
                let name = parts[8...].joined(separator: " ")
                guard name != "." && name != ".." else { return nil }
                let size = Int64(parts[4]) ?? 0
                let path = (basePath as NSString).appendingPathComponent(name)
                return FileItem(name: name, path: path, isDirectory: permissions.hasPrefix("d"), size: size)
            }
            .sorted { ($0.isDirectory && !$1.isDirectory) || ($0.isDirectory == $1.isDirectory && $0.name < $1.name) }
    }
}

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let mode: String

    init(name: String, path: String, isDirectory: Bool, size: Int64, mode: String = "-") {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.size = size
        self.mode = mode
    }
    
    var isRegularFile: Bool { mode == "-" }
    var icon: String {
        if isDirectory { return "folder.fill" }
        if mode == "l" { return "link" }
        if isRegularFile { return "doc.fill" }
        return "doc.badge.gearshape"
    }
    var sizeText: String {
        if isDirectory { return "--" }
        if size < 1024 { return "\(size) B" }
        if size < 1024*1024 { return String(format: "%.1f KB", Double(size)/1024) }
        return String(format: "%.1f MB", Double(size)/(1024*1024))
    }
    
    static func == (a: FileItem, b: FileItem) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
