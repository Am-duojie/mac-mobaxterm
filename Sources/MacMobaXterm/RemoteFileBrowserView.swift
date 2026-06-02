import SwiftUI

struct RemoteFileBrowserView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var session: Session
    @State private var remoteFiles: [FileItem] = []
    @State private var remoteStatus: String = "正在读取远程目录..."
    @State private var pathText: String = "~"
    @State private var isLoading: Bool = false
    @State private var selectedRemote: FileItem?
    @State private var bookmarkedPaths: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text("SFTP")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.55)
                        .frame(width: 16, height: 16)
                }
                Button { loadRemoteFiles(path: pathText) } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .help("刷新远程目录")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            HStack(spacing: 4) {
                Menu {
                    Button("收藏当前路径") { addBookmark() }
                    Divider()
                    if bookmarkedPaths.isEmpty {
                        Text("暂无收藏")
                    } else {
                        ForEach(bookmarkedPaths, id: \.self) { path in
                            Button(path) { loadRemoteFiles(path: path) }
                        }
                    }
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .frame(width: 19, height: 19)
                }
                .menuStyle(.borderlessButton)
                .help("远程路径收藏")
                iconButton("house.fill", "Home 目录") { loadRemoteFiles(path: "~") }
                Button { goUp() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10))
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("上级目录")
                iconButton("arrow.down.to.line", "下载到 Downloads") { downloadSelected() }
                iconButton("arrow.up.to.line", "上传文件") { uploadFile() }
                iconButton("arrow.clockwise.circle.fill", "刷新") { loadRemoteFiles(path: pathText) }
                iconButton("folder.badge.plus", "新建文件夹") { createFolder() }
                iconButton("trash.fill", "删除") { deleteSelected() }

                TextField("远程路径", text: $pathText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 10))
                    .onSubmit { loadRemoteFiles(path: pathText) }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            Divider()

            if remoteFiles.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text(remoteStatus)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .padding(.horizontal, 12)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(remoteFiles) { file in
                            RemoteFileRow(
                                file: file,
                                isSelected: selectedRemote?.path == file.path,
                                onSelect: { selectedRemote = file },
                                onOpen: {
                                    selectedRemote = file
                                    if file.isDirectory { loadRemoteFiles(path: file.path) }
                                },
                                onDownload: {
                                    selectedRemote = file
                                    downloadSelected()
                                },
                                onDelete: {
                                    selectedRemote = file
                                    deleteSelected()
                                }
                            )
                        }
                    }
                }
            }

            if !remoteStatus.isEmpty && !isLoading {
                Divider()
                Text(remoteStatus)
                    .font(.system(size: 10))
                    .foregroundStyle(remoteStatus.contains("完成") ? .green : .secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
        }
        .frame(minHeight: 220)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            loadBookmarks()
            pathText = normalizedInitialPath()
            loadRemoteFiles(path: pathText)
        }
        .onChange(of: session.id) { _, _ in
            pathText = normalizedInitialPath()
            loadRemoteFiles(path: pathText)
        }
        .onChange(of: session.remoteBrowserPath) { _, newPath in
            guard !newPath.isEmpty, newPath != pathText else { return }
            pathText = newPath
            loadRemoteFiles(path: newPath)
        }
    }

    private func iconButton(_ icon: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 19, height: 19)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func normalizedInitialPath() -> String {
        if !session.remoteBrowserPath.isEmpty { return session.remoteBrowserPath }
        if let path = session.connection?.remotePath, !path.isEmpty { return path }
        return "~"
    }

    private var bookmarkStorageKey: String {
        let account = session.connection?.credentialId ?? session.id.uuidString
        return "MacMobaXterm.RemoteBookmarks.\(account)"
    }

    private func loadBookmarks() {
        bookmarkedPaths = UserDefaults.standard.stringArray(forKey: bookmarkStorageKey) ?? []
    }

    private func addBookmark() {
        let path = remoteResolvedPath()
        guard !bookmarkedPaths.contains(path) else { return }
        bookmarkedPaths.append(path)
        UserDefaults.standard.set(bookmarkedPaths, forKey: bookmarkStorageKey)
    }

    private func goUp() {
        let path = pathText.trimmingCharacters(in: .whitespacesAndNewlines)
        if path == "/" || path == "~" || path.isEmpty { return }
        if path.hasPrefix("~/") {
            let parent = String(path.dropLastPathComponent)
            loadRemoteFiles(path: parent.isEmpty ? "~" : parent)
        } else {
            let parent = (path as NSString).deletingLastPathComponent
            loadRemoteFiles(path: parent.isEmpty ? "/" : parent)
        }
    }

    private func loadRemoteFiles(path: String) {
        guard let connection = session.connection else {
            remoteFiles = []
            remoteStatus = "没有可用的连接"
            return
        }

        let conn = connection
        guard session.type == .ssh || session.type == .sftp else {
            remoteFiles = []
            remoteStatus = "当前会话不是 SSH/SFTP"
            return
        }

        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePath = trimmedPath.isEmpty ? "~" : trimmedPath
        pathText = effectivePath
        session.remoteBrowserPath = effectivePath
        isLoading = true
        remoteStatus = "正在读取远程目录..."

        DispatchQueue.global().async {
            let result = runRemoteList(connection: conn, path: effectivePath)
            let parsed = result.succeeded ? parseRemoteListing(result.output, fallbackPath: effectivePath) : nil
            DispatchQueue.main.async {
                isLoading = false
                if let parsed {
                    pathText = parsed.path
                    session.remoteBrowserPath = parsed.path
                    remoteFiles = parsed.files
                    if let selectedRemote, !parsed.files.contains(where: { $0.path == selectedRemote.path }) {
                        self.selectedRemote = nil
                    }
                    remoteStatus = parsed.files.isEmpty ? "目录为空" : ""
                } else {
                    remoteFiles = []
                    remoteStatus = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
    }

    private func uploadFile() {
        guard let connection = session.connection else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let conn = connection
        let destination = "\(remoteResolvedPath())/\(url.lastPathComponent)"
        runTransfer(connection: conn, local: url.path, remote: destination, upload: true, recursive: false) { result in
            if result.succeeded {
                remoteStatus = "上传完成: \(url.lastPathComponent)"
                loadRemoteFiles(path: pathText)
            }
        }
    }

    private func downloadSelected() {
        guard let connection = session.connection else { return }
        guard let selectedRemote else {
            remoteStatus = "请先选择一个远程文件"
            return
        }
        guard selectedRemote.isDirectory || selectedRemote.isRegularFile else {
            remoteStatus = "不能下载设备文件、管道或符号链接: \(selectedRemote.name)"
            return
        }
        let conn = connection
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path ?? NSHomeDirectory()
        runTransfer(connection: conn, local: downloads, remote: selectedRemote.path, upload: false, recursive: selectedRemote.isDirectory) { result in
            if result.succeeded {
                remoteStatus = "下载完成: ~/Downloads/\(selectedRemote.name)"
            }
        }
    }

    private func createFolder() {
        guard let connection = session.connection else { return }
        let alert = NSAlert()
        alert.messageText = "新建远程文件夹"
        alert.informativeText = "输入文件夹名称"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = "new-folder"
        alert.accessoryView = field
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let conn = connection
        let command = "mkdir -p \(remoteShellPath(remoteResolvedPath() + "/" + name))"
        runRemoteCommand(connection: conn, command: command) {
            loadRemoteFiles(path: pathText)
        }
    }

    private func deleteSelected() {
        guard let connection = session.connection, let selectedRemote else { return }
        let alert = NSAlert()
        alert.messageText = "删除远程项目？"
        alert.informativeText = selectedRemote.path
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let conn = connection
        let command = selectedRemote.isDirectory ? "rm -rf \(selectedRemote.path.shellQuoted)" : "rm -f \(selectedRemote.path.shellQuoted)"
        runRemoteCommand(connection: conn, command: command) {
            loadRemoteFiles(path: pathText)
        }
    }

    private func remoteResolvedPath() -> String {
        let path = pathText.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? "~" : path
    }

    private func runRemoteCommand(connection conn: Connection, command: String, completion: @escaping () -> Void) {
        DispatchQueue.global().async {
            var args = SSHRuntimeOptions.baseArgs(port: conn.port)
            if (conn.authMethod == .key || conn.authMethod == .keyWithPassphrase), !conn.privateKeyPath.isEmpty {
                args += ["-i", conn.privateKeyPath]
            }
            let target = conn.username.isEmpty ? conn.host : "\(conn.username)@\(conn.host)"
            args += [target, command]
            _ = runAuthenticated("/usr/bin/ssh", args: args, connection: conn, timeout: 14)
            DispatchQueue.main.async { completion() }
        }
    }

    private func runTransfer(connection conn: Connection, local: String, remote: String, upload: Bool, recursive: Bool, completion: @escaping (CommandResult) -> Void) {
        isLoading = true
        remoteStatus = upload ? "正在上传..." : "正在下载..."
        DispatchQueue.global().async {
            var args = SSHRuntimeOptions.baseArgs(port: conn.port)
            if let portIndex = args.firstIndex(of: "-p"), portIndex + 1 < args.count {
                args.removeSubrange(portIndex...(portIndex + 1))
            }
            args += ["-P", "\(conn.port)"]
            if recursive {
                args.append("-r")
            }
            if (conn.authMethod == .key || conn.authMethod == .keyWithPassphrase), !conn.privateKeyPath.isEmpty {
                args += ["-i", conn.privateKeyPath]
            }
            let target = conn.username.isEmpty ? conn.host : "\(conn.username)@\(conn.host)"
            if upload {
                args += [local, "\(target):\(remote)"]
            } else {
                args += ["\(target):\(remote)", local]
            }
            let result = runAuthenticated("/usr/bin/scp", args: args, connection: conn, timeout: 60)
            DispatchQueue.main.async {
                isLoading = false
                if !result.succeeded {
                    let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    remoteStatus = message.isEmpty ? "传输失败" : message
                }
                completion(result)
            }
        }
    }

    private func runAuthenticated(_ executable: String, args: [String], connection conn: Connection, timeout: TimeInterval) -> CommandResult {
        if conn.authMethod == .password, !conn.password.isEmpty {
            return CommandRunner.runExpectingPassword(executable, args, password: conn.password, timeout: timeout)
        }
        if conn.authMethod == .keyWithPassphrase, !conn.passphrase.isEmpty {
            return CommandRunner.runExpectingPassword(executable, args, password: conn.passphrase, timeout: timeout)
        }
        return CommandRunner.run(executable, args, timeout: timeout)
    }

    private func runRemoteList(connection conn: Connection, path: String) -> CommandResult {
        var args = SSHRuntimeOptions.baseArgs(port: conn.port)
        if (conn.authMethod == .key || conn.authMethod == .keyWithPassphrase), !conn.privateKeyPath.isEmpty {
            args += ["-i", conn.privateKeyPath]
        }
        if conn.authMethod == .key || conn.authMethod == .keyWithPassphrase || conn.password.isEmpty {
            args += ["-o", "BatchMode=yes"]
        }
        let target = conn.username.isEmpty ? conn.host : "\(conn.username)@\(conn.host)"
        let command = "cd \(remoteShellPath(path)) && pwd && echo __MACMOBAXTERM_LS__ && LC_ALL=C ls -la"
        args += [target, command]

        if conn.authMethod == .password, !conn.password.isEmpty {
            return CommandRunner.runExpectingPassword("/usr/bin/ssh", args, password: conn.password, timeout: 14)
        }
        if conn.authMethod == .keyWithPassphrase, !conn.passphrase.isEmpty {
            return CommandRunner.runExpectingPassword("/usr/bin/ssh", args, password: conn.passphrase, timeout: 14)
        }
        return CommandRunner.run("/usr/bin/ssh", args, timeout: 14)
    }

    private func remoteShellPath(_ path: String) -> String {
        if path == "~" { return "$HOME" }
        if path.hasPrefix("~/") {
            let rest = String(path.dropFirst(2))
            return rest.isEmpty ? "$HOME" : "$HOME/\(rest.shellQuoted)"
        }
        return path.shellQuoted
    }

    private func parseRemoteListing(_ output: String, fallbackPath: String) -> (path: String, files: [FileItem])? {
        let lines = output
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard let markerIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == "__MACMOBAXTERM_LS__" }) else {
            return nil
        }
        let resolvedPath = lines[..<markerIndex]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .last { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("password:") } ?? fallbackPath
        let files = lines[(markerIndex + 1)...]
            .compactMap { line -> FileItem? in
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 9 else { return nil }
                let permissions = String(parts[0])
                let mode = String(permissions.prefix(1))
                let name = parts[8...].joined(separator: " ")
                guard name != "." && name != ".." else { return nil }
                let size = Int64(parts[4]) ?? 0
                let fullPath = resolvedPath == "/" ? "/\(name)" : "\(resolvedPath)/\(name)"
                return FileItem(name: name, path: fullPath, isDirectory: permissions.hasPrefix("d"), size: size, mode: mode)
            }
            .sorted { ($0.isDirectory && !$1.isDirectory) || ($0.isDirectory == $1.isDirectory && $0.name < $1.name) }
        return (resolvedPath, files)
    }
}

struct RemoteFileRow: View {
    let file: FileItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: file.icon)
                .font(.system(size: 12))
                .foregroundStyle(file.isDirectory ? .blue : .secondary)
                .frame(width: 18)
            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(file.sizeText)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(height: 27)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
                .padding(.leading, 28)
        }
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onOpen() }
        .contextMenu {
            Button("打开") { onOpen() }
            Button("下载到 Downloads") { onDownload() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}

private extension String {
    var dropLastPathComponent: String {
        let components = split(separator: "/", omittingEmptySubsequences: false)
        guard components.count > 1 else { return "" }
        return components.dropLast().joined(separator: "/")
    }
}
