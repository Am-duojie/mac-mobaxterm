import SwiftUI

struct SessionEditorView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @State private var connection = Connection()
    @State private var selectedTab: EditorTab = .basic
    @State private var selectedFolderId: UUID?
    @State private var testResult: String = ""
    @State private var isTesting = false
    @State private var sessionType: SessionType = .ssh
    @State private var serialPort: String = "/dev/tty.usbserial"
    @State private var serialBaud: Int = 115200
    @AppStorage("defaultPort") private var defaultSSHPort: Int = 22
    @AppStorage("defaultAuthMethod") private var defaultAuth: String = "password"
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable { case host, username, password, name, port, key, passphrase, remotePath, serial }
    
    enum SessionType: String, CaseIterable {
        case ssh = "SSH", shell = "Shell", telnet = "Telnet"
        case rdp = "RDP", sftp = "SFTP", ftp = "FTP"
        case serial = "Serial", vnc = "VNC"
        var icon: String {
            switch self {
            case .ssh: return "terminal"; case .shell: return "terminal.fill"
            case .sftp: return "arrow.triangle.2.circlepath"; case .telnet: return "globe"
            case .rdp: return "display"; case .serial: return "cable.connector"
            case .ftp: return "folder"; case .vnc: return "macwindow"
            }
        }
        var needsHost: Bool { self != .shell && self != .serial }
        var tabType: TabType {
            switch self {
            case .ssh: return .ssh
            case .shell: return .local
            case .telnet: return .telnet
            case .rdp: return .rdp
            case .sftp: return .sftp
            case .ftp: return .ftp
            case .serial: return .serial
            case .vnc: return .vnc
            }
        }
        var defaultPort: Int {
            switch self {
            case .ssh: return 22; case .telnet: return 23; case .rdp: return 3389
            case .ftp: return 21; case .vnc: return 5900; case .sftp: return 22
            default: return 0
            }
        }
        
        init(tabType: TabType) {
            switch tabType {
            case .ssh: self = .ssh
            case .local: self = .shell
            case .telnet: self = .telnet
            case .rdp: self = .rdp
            case .sftp: self = .sftp
            case .ftp: self = .ftp
            case .serial: self = .serial
            case .vnc: self = .vnc
            }
        }
    }
    
    private var isEditing: Bool { sessionManager.editingConnection != nil }
    enum EditorTab: String, CaseIterable {
        case basic = "基本设置", advanced = "高级设置", terminal = "终端设置"
        var icon: String {
            switch self {
            case .basic: return "gear"
            case .advanced: return "gearshape.2"
            case .terminal: return "terminal"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Text(isEditing ? "编辑会话" : "选择会话类型...").font(.system(size: 14, weight: .medium))
                Spacer()
            }.padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            
            // 会话类型
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SessionType.allCases, id: \.self) { type in
                        Button {
                            sessionType = type
                            connection.type = type.tabType
                            connection.port = type == .ssh ? defaultSSHPort : type.defaultPort
                            if type == .ssh {
                                connection.authMethod = AuthMethod(rawValue: defaultAuth) ?? .password
                            }
                            if type == .shell {
                                sessionManager.openLocalSession()
                                closeWindow()
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 22))
                                    .foregroundColor(sessionType == type ? .white : .blue)
                                Text(type.rawValue)
                                    .font(.system(size: 12, weight: sessionType == type ? .bold : .medium))
                                    .foregroundColor(sessionType == type ? .white : .primary)
                            }
                            .frame(width: 72, height: 65)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(sessionType == type ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                            )
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal, 16).padding(.vertical, 10)
            }
            Divider()
            
            if sessionType == .shell {
                VStack { Spacer(); Text("本地终端已启动").foregroundStyle(.secondary); Spacer() }.padding(40)
            } else {
                // 标签页 - 大按钮风格
                HStack(spacing: 8) {
                    ForEach(EditorTab.allCases, id: \.self) { tab in
                        Button { selectedTab = tab } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon).font(.system(size: 14))
                                Text(tab.rawValue).font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .contentShape(Rectangle())
                            .foregroundColor(selectedTab == tab ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTab == tab ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                            )
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                }.padding(.horizontal, 16)
                Divider()
                
                // 表单内容
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selectedTab {
                        case .basic: formContent.padding(.top, 4)
                        case .advanced: advancedContent.padding(.top, 4)
                        case .terminal: terminalContent.padding(.top, 4)
                        }
                    }.padding(16)
                }
                
                Divider()
                
                // 底部按钮
                HStack {
                    if !connection.host.isEmpty && sessionType.needsHost {
                        Button { testConnection() } label: {
                            if isTesting { ProgressView().controlSize(.small) } else { Text("测试连接") }
                        }.disabled(isTesting)
                        if !testResult.isEmpty {
                            Text(testResult).font(.caption).foregroundStyle(testResult.contains("成功") ? .green : .red)
                        }
                    }
                    Spacer()
                    Button("取消") { closeWindow() }.keyboardShortcut(.escape)
                    Button("确定") { saveAndConnect() }.keyboardShortcut(.return).buttonStyle(.borderedProminent)
                        .disabled(sessionType.needsHost && connection.host.isEmpty)
                }.padding(12)
            }
        }
        .frame(width: 580, height: 480)
        .onAppear {
            if let e = sessionManager.editingConnection {
                connection = e
                sessionType = SessionType(tabType: e.type)
                serialPort = e.serialPort
                serialBaud = e.serialBaud
            } else {
                connection.port = defaultSSHPort
                connection.authMethod = AuthMethod(rawValue: defaultAuth) ?? .password
            }
            // 自动聚焦第一个输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focusedField = .host }
        }
    }
    
    // MARK: - 动态表单
    @ViewBuilder
    private var formContent: some View {
        switch sessionType {
        case .ssh, .sftp:
            FieldRow(label: "远程主机 (*):") {
                TextField("192.168.1.1", text: $connection.host).textFieldStyle(.roundedBorder).focused($focusedField, equals: .host)
            }
            FieldRow(label: "用户名:") {
                TextField("root", text: $connection.username).textFieldStyle(.roundedBorder).focused($focusedField, equals: .username)
            }
            FieldRow(label: "端口:") {
                TextField("22", value: $connection.port, format: .number).textFieldStyle(.roundedBorder).frame(width: 70).focused($focusedField, equals: .port)
            }
            FieldRow(label: "显示名称:") {
                TextField("我的服务器", text: $connection.name).textFieldStyle(.roundedBorder).focused($focusedField, equals: .name)
            }
            FieldRow(label: "认证:") {
                Picker("", selection: $connection.authMethod) {
                    ForEach(AuthMethod.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }.pickerStyle(.segmented)
            }
            authFields
            
        case .telnet:
            FieldRow(label: "远程主机 (*):") {
                TextField("192.168.1.1", text: $connection.host).textFieldStyle(.roundedBorder).focused($focusedField, equals: .host)
            }
            FieldRow(label: "端口:") {
                TextField("23", value: $connection.port, format: .number).textFieldStyle(.roundedBorder).frame(width: 70)
            }
            FieldRow(label: "用户名:") {
                TextField("admin", text: $connection.username).textFieldStyle(.roundedBorder).focused($focusedField, equals: .username)
            }
            FieldRow(label: "显示名称:") {
                TextField("交换机", text: $connection.name).textFieldStyle(.roundedBorder).focused($focusedField, equals: .name)
            }
            
        case .rdp:
            FieldRow(label: "远程主机 (*):") {
                TextField("192.168.1.1", text: $connection.host).textFieldStyle(.roundedBorder).focused($focusedField, equals: .host)
            }
            FieldRow(label: "端口:") {
                TextField("3389", value: $connection.port, format: .number).textFieldStyle(.roundedBorder).frame(width: 70)
            }
            FieldRow(label: "用户名:") {
                TextField("用户名", text: $connection.username).textFieldStyle(.roundedBorder).focused($focusedField, equals: .username)
            }
            FieldRow(label: "密码:") {
                SecureField("密码", text: $connection.password).textFieldStyle(.roundedBorder).focused($focusedField, equals: .password)
            }
            FieldRow(label: "显示名称:") {
                TextField("Windows服务器", text: $connection.name).textFieldStyle(.roundedBorder).focused($focusedField, equals: .name)
            }
            
        case .ftp:
            FieldRow(label: "远程主机 (*):") {
                TextField("ftp.example.com", text: $connection.host).textFieldStyle(.roundedBorder).focused($focusedField, equals: .host)
            }
            FieldRow(label: "端口:") {
                TextField("21", value: $connection.port, format: .number).textFieldStyle(.roundedBorder).frame(width: 70)
            }
            FieldRow(label: "用户名:") {
                TextField("anonymous", text: $connection.username).textFieldStyle(.roundedBorder).focused($focusedField, equals: .username)
            }
            FieldRow(label: "密码:") {
                SecureField("密码", text: $connection.password).textFieldStyle(.roundedBorder).focused($focusedField, equals: .password)
            }
            
        case .vnc:
            FieldRow(label: "远程主机 (*):") {
                TextField("192.168.1.1", text: $connection.host).textFieldStyle(.roundedBorder).focused($focusedField, equals: .host)
            }
            FieldRow(label: "端口:") {
                TextField("5900", value: $connection.port, format: .number).textFieldStyle(.roundedBorder).frame(width: 70)
            }
            FieldRow(label: "密码:") {
                SecureField("VNC密码", text: $connection.password).textFieldStyle(.roundedBorder).focused($focusedField, equals: .password)
            }
            FieldRow(label: "显示名称:") {
                TextField("Mac Mini", text: $connection.name).textFieldStyle(.roundedBorder).focused($focusedField, equals: .name)
            }
            
        case .serial:
            FieldRow(label: "串口设备:") {
                HStack {
                    TextField("/dev/tty.usbserial", text: $serialPort).textFieldStyle(.roundedBorder).focused($focusedField, equals: .serial)
                    Menu("选择...") {
                        let ports = availableSerialPorts()
                        if ports.isEmpty {
                            Text("未发现串口设备")
                        } else {
                            ForEach(ports, id: \.self) { port in
                                Button(port) { serialPort = port }
                            }
                        }
                    }
                }
            }
            FieldRow(label: "波特率:") {
                Picker("", selection: $serialBaud) {
                    Text("9600").tag(9600)
                    Text("19200").tag(19200)
                    Text("38400").tag(38400)
                    Text("57600").tag(57600)
                    Text("115200").tag(115200)
                    Text("230400").tag(230400)
                    Text("460800").tag(460800)
                    Text("921600").tag(921600)
                }
            }
            FieldRow(label: "显示名称:") {
                TextField("串口终端", text: $connection.name).textFieldStyle(.roundedBorder).focused($focusedField, equals: .name)
            }
            Divider().padding(.vertical, 4)
            Text("提示: 使用 Ctrl+A 然后 K 退出 screen 串口会话")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            
        default: EmptyView()
        }
    }
    
    @ViewBuilder private var authFields: some View {
        switch connection.authMethod {
        case .password:
            FieldRow(label: "密码:") {
                SecureField("密码", text: $connection.password).textFieldStyle(.roundedBorder).focused($focusedField, equals: .password)
            }
        case .key, .keyWithPassphrase:
            FieldRow(label: "私钥:") {
                HStack {
                    TextField("~/.ssh/id_rsa", text: $connection.privateKeyPath).textFieldStyle(.roundedBorder).focused($focusedField, equals: .key)
                    Button("浏览...") { pickPrivateKey() }
                }
            }
            if connection.authMethod == .keyWithPassphrase {
                FieldRow(label: "密码短语:") {
                    SecureField("密码短语", text: $connection.passphrase).textFieldStyle(.roundedBorder).focused($focusedField, equals: .passphrase)
                }
            }
        }
    }
    
    // MARK: - 高级设置
    @ViewBuilder
    private var advancedContent: some View {
        if sessionType == .serial {
            FieldRow(label: "数据位:") {
                Picker("", selection: $connection.serialDataBits) {
                    Text("5").tag(5); Text("6").tag(6); Text("7").tag(7); Text("8").tag(8)
                }.pickerStyle(.segmented).frame(width: 200)
            }
            FieldRow(label: "停止位:") {
                Picker("", selection: $connection.serialStopBits) {
                    Text("1").tag(1); Text("2").tag(2)
                }.pickerStyle(.segmented).frame(width: 100)
            }
            FieldRow(label: "校验位:") {
                Picker("", selection: $connection.serialParity) {
                    Text("无").tag("N"); Text("奇校验").tag("O"); Text("偶校验").tag("E")
                }.pickerStyle(.segmented).frame(width: 200)
            }
            FieldRow(label: "流控:") {
                Picker("", selection: $connection.serialFlowControl) {
                    Text("无").tag("none"); Text("硬件").tag("hardware"); Text("软件").tag("software")
                }.pickerStyle(.segmented).frame(width: 200)
            }
            Divider().padding(.vertical, 8)
            Text("当前配置: " + String(connection.serialDataBits) + connection.serialParity + String(connection.serialStopBits))
                .font(.system(size: 14, design: .monospaced)).foregroundStyle(.secondary)
        } else {
            FieldRow(label: "远程路径:") { TextField("/home/user", text: $connection.remotePath).textFieldStyle(.roundedBorder) }
            FieldRow(label: "颜色标记:") {
                HStack(spacing: 8) {
                    ForEach(["blue","green","red","orange","yellow","purple"], id: \.self) { c in
                        Circle().fill(colorForTag(c)).frame(width: 18, height: 18)
                            .overlay(Circle().stroke(Color.accentColor, lineWidth: connection.colorTag == c ? 2 : 0))
                            .onTapGesture { connection.colorTag = c }
                    }
                }
            }
            Toggle("收藏此会话", isOn: $connection.isFavorite)
            if !sessionManager.folders.isEmpty {
                FieldRow(label: "保存到:") {
                    Picker("", selection: $selectedFolderId) {
                        Text("默认").tag(nil as UUID?)
                        ForEach(sessionManager.folders) { Text($0.name).tag($0.id as UUID?) }
                    }
                }
            }
        }
    }
    
    // MARK: - 终端设置
    private var terminalContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("终端类型: xterm-256color", systemImage: "terminal")
            Label("编码: UTF-8", systemImage: "doc.text")
            Label("字体: 等宽 14pt", systemImage: "textformat")
        }.font(.system(size: 13)).foregroundStyle(.secondary)
    }
    
    // MARK: - 操作
    private func saveAndConnect() {
        connection.type = sessionType.tabType
        if sessionType == .serial {
            connection.serialPort = serialPort
            connection.serialBaud = serialBaud
            connection.host = serialPort
            connection.port = serialBaud
        }
        if isEditing { sessionManager.updateConnection(connection) }
        else { sessionManager.addConnection(connection, to: selectedFolderId) }
        switch sessionType {
        case .ssh: sessionManager.openSSH(connection)
        case .sftp: sessionManager.openSFTP(connection)
        case .telnet: sessionManager.openTelnet(connection)
        case .rdp: sessionManager.openRDP(connection)
        case .ftp: sessionManager.openFTP(connection)
        case .vnc: sessionManager.openVNC(connection)
        case .serial: sessionManager.openSerial(connection, port: serialPort, baud: serialBaud)
        case .shell: break
        }
        closeWindow()
    }
    
    private func testConnection() {
        isTesting = true; testResult = ""
        DispatchQueue.global().async {
            let target = connection.username.isEmpty ? connection.host : "\(connection.username)@\(connection.host)"
            let result = CommandRunner.run(
                "/usr/bin/ssh",
                ["-o","ConnectTimeout=5","-o","StrictHostKeyChecking=no","-o","BatchMode=yes",
                 "-p","\(connection.port)", target, "echo OK"],
                timeout: 8
            )
            DispatchQueue.main.async {
                isTesting = false
                testResult = result.succeeded && result.output.contains("OK") ? "连接成功" : "连接失败: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines))"
            }
        }
    }
    
    private func availableSerialPorts() -> [String] {
        let fm = FileManager.default
        let devPath = "/dev/"
        guard let items = try? fm.contentsOfDirectory(atPath: devPath) else { return [] }
        return items
            .filter { $0.hasPrefix("tty.") || $0.hasPrefix("cu.") || $0.hasPrefix("ttys") }
            .sorted()
            .map { "/dev/" + $0 }
    }
    
    private func pickPrivateKey() {
        let p = NSOpenPanel(); p.title = "选择SSH私钥"
        p.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        if p.runModal() == .OK, let u = p.url { connection.privateKeyPath = u.path }
    }
    
    private func closeWindow() {
        sessionManager.showConnectionEditor = false
        NSApp.keyWindow?.close()
    }
    
    private func colorForTag(_ t: String) -> Color {
        switch t { case "red": return .red; case "orange": return .orange; case "yellow": return .yellow
        case "green": return .green; case "blue": return .blue; case "purple": return .purple
        default: return .gray }
    }
}

// MARK: - 表单行
struct FieldRow<Content: View>: View {
    let label: String; @ViewBuilder let content: () -> Content
    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 12)).frame(width: 100, alignment: .trailing)
            content()
        }
    }
}
