import SwiftUI
import SwiftTerm

struct TerminalSessionView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @ObservedObject var session: Session
    @AppStorage("showConnectionStatusBar") private var showConnectionStatusBar: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            if showConnectionStatusBar {
                HStack(spacing: 6) {
                    Circle().fill(session.isConnected ? .green : .orange).frame(width: 6, height: 6)
                    Text(session.statusMessage).font(.caption).foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    if let conn = session.connection {
                        Text(session.type == .serial ? "\(conn.serialPort) @ \(conn.serialBaud)" : "\(conn.host):\(conn.port)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(red: 0.06, green: 0.07, blue: 0.08))
            }
            
            if session.type == .rdp || session.type == .vnc {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: session.icon).font(.system(size: 48)).foregroundStyle(.secondary)
                    Text(session.statusMessage).font(.title3)
                    if let conn = session.connection { Text("\(conn.host):\(conn.port)").foregroundStyle(.secondary) }
                    Text("已在系统客户端中打开").font(.caption).foregroundStyle(.tertiary)
                    Spacer()
                }.frame(maxWidth: .infinity).background(Color.black)
            } else if sessionManager.showConnectionEditor || sessionManager.showSettings  {
                // 编辑器打开时，显示占位符（终端不加载）
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "keyboard").font(.system(size: 32)).foregroundStyle(.tertiary)
                    Text("请在弹出窗口中操作").foregroundStyle(.secondary)
                    Spacer()
                }.frame(maxWidth: .infinity).background(Color.black)
            } else {
                SwiftTerminalHost(session: session)
                    .background(Color.black)
            }
        }
        .background(Color.black)
    }
}

struct SwiftTerminalHost: NSViewRepresentable {
    @ObservedObject var session: Session
    
    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminal = LocalProcessTerminalView(frame: .zero)
        let fontSize = UserDefaults.standard.double(forKey: "terminalFontSize")
        terminal.processDelegate = context.coordinator
        terminal.font = NSFont(name: "Menlo", size: fontSize > 0 ? fontSize : 14) ?? NSFont.monospacedSystemFont(ofSize: fontSize > 0 ? fontSize : 14, weight: .regular)
        terminal.wantsLayer = true
        terminal.nativeForegroundColor = NSColor.white
        terminal.nativeBackgroundColor = NSColor.black
        terminal.caretColor = NSColor.white
        terminal.caretTextColor = NSColor.black
        terminal.selectedTextBackgroundColor = NSColor.selectedTextBackgroundColor
        terminal.useBrightColors = true
        terminal.allowMouseReporting = true
        terminal.layer?.backgroundColor = NSColor.black.cgColor
        terminal.needsDisplay = true
        startProcess(on: terminal)
        return terminal
    }
    
    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }
    
    private func startProcess(on terminal: LocalProcessTerminalView) {
        let env = TerminalEnvironment.env()
        switch session.type {
        case .local:
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            terminal.startProcess(executable: shell, args: ["-l"], environment: env)
        case .ssh:
            guard let conn = session.connection else { return }
            var args = SSHRuntimeOptions.baseArgs(port: conn.port)
            if (conn.authMethod == .key || conn.authMethod == .keyWithPassphrase), !conn.privateKeyPath.isEmpty { args += ["-i", conn.privateKeyPath] }
            let target = conn.username.isEmpty ? conn.host : "\(conn.username)@\(conn.host)"
            if !conn.remotePath.isEmpty {
                args.append("-t")
            }
            args.append(target)
            if !conn.remotePath.isEmpty {
                args.append("cd \(conn.remotePath.shellQuoted) && exec $SHELL -l")
            }
            terminal.startProcess(executable: "/usr/bin/ssh", args: args, environment: env)
        case .sftp:
            guard let conn = session.connection else { return }
            var args = SSHRuntimeOptions.sftpArgs(port: conn.port)
            if (conn.authMethod == .key || conn.authMethod == .keyWithPassphrase), !conn.privateKeyPath.isEmpty { args += ["-i", conn.privateKeyPath] }
            let target = conn.username.isEmpty ? conn.host : "\(conn.username)@\(conn.host)"
            args.append(target)
            terminal.startProcess(executable: "/usr/bin/sftp", args: args, environment: env)
        case .telnet:
            guard let conn = session.connection else { return }
            terminal.startProcess(executable: "/usr/bin/telnet", args: [conn.host, "\(conn.port)"], environment: env)
        case .ftp:
            guard let conn = session.connection else { return }
            terminal.startProcess(executable: "/usr/bin/ftp", args: [conn.host, "\(conn.port)"], environment: env)
        case .serial:
            let conn = session.connection
            let port = conn?.serialPort ?? conn?.host ?? "/dev/tty.usbserial"
            let baud = String(conn?.serialBaud ?? conn?.port ?? 115200)
            let dataBits = conn?.serialDataBits ?? 8
            let parity = conn?.serialParity ?? "N"
            let stopBits = conn?.serialStopBits ?? 1
            // screen 格式: screen /dev/tty.xxx 115200 8N1
            let format = "\(dataBits)\(parity)\(stopBits)"
            terminal.startProcess(executable: "/usr/bin/screen", args: [port, baud, format], environment: env)
        case .rdp, .vnc: break
        }
    }
    
    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        let session: Session
        init(session: Session) { self.session = session }
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            DispatchQueue.main.async { self.session.title = title }
        }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async {
                self.session.isConnected = false
                self.session.statusMessage = exitCode != nil ? "已断开 (退出码: \(exitCode!))" : "已断开"
            }
        }
    }
}

enum SSHRuntimeOptions {
    static func baseArgs(port: Int) -> [String] {
        let defaults = UserDefaults.standard
        let timeout = max(defaults.integer(forKey: "connectTimeout"), 5)
        let keepAlive = defaults.integer(forKey: "keepAliveInterval")
        let strictHostKey = defaults.bool(forKey: "strictHostKey")
        var args = [
            "-o", "StrictHostKeyChecking=\(strictHostKey ? "yes" : "accept-new")",
            "-o", "ConnectTimeout=\(timeout)",
            "-p", "\(port)"
        ]
        if keepAlive > 0 {
            args += ["-o", "ServerAliveInterval=\(keepAlive)"]
        }
        return args
    }
    
    static func sftpArgs(port: Int) -> [String] {
        var args = baseArgs(port: port)
        if let portIndex = args.firstIndex(of: "-p"), portIndex + 1 < args.count {
            args[portIndex] = "-P"
        }
        return args
    }
}

extension String {
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

enum TerminalEnvironment {
    static func env() -> [String] {
        var e = ProcessInfo.processInfo.environment
        e["TERM"] = "xterm-256color"; e["COLORTERM"] = "truecolor"; e["LC_ALL"] = "en_US.UTF-8"
        return e.map { "\($0.key)=\($0.value)" }
    }
}
