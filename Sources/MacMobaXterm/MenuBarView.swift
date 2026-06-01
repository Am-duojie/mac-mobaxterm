import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @Binding var showSFTP: Bool
    @Binding var showNetworkTools: Bool
    @Binding var showSettings: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            MenuBtn("终端") {
                let m = NSMenu()
                m.addItem(withTitle: "新建本地终端", action: #selector(Acts.a1), keyEquivalent: "")
                m.addItem(withTitle: "新建SSH连接", action: #selector(Acts.a2), keyEquivalent: "")
                m.addItem(.separator())
                m.addItem(withTitle: "关闭当前标签", action: #selector(Acts.a3), keyEquivalent: "")
                m.addItem(withTitle: "关闭全部标签", action: #selector(Acts.a4), keyEquivalent: "")
                return m
            }
            MenuBtn("会话") {
                let m = NSMenu()
                m.addItem(withTitle: "新建会话...", action: #selector(Acts.a2), keyEquivalent: "")
                m.addItem(.separator())
                m.addItem(withTitle: "导入会话...", action: #selector(Acts.a5), keyEquivalent: "")
                m.addItem(withTitle: "导出会话...", action: #selector(Acts.a6), keyEquivalent: "")
                return m
            }
            MenuBtn("视图") {
                let m = NSMenu()
                m.addItem(withTitle: showSFTP ? "隐藏SFTP" : "显示SFTP", action: #selector(Acts.a7), keyEquivalent: "")
                return m
            }
            MenuBtn("工具") {
                let m = NSMenu()
                m.addItem(withTitle: "网络工具箱...", action: #selector(Acts.a8), keyEquivalent: "")
                m.addItem(.separator())
                m.addItem(withTitle: "SSH密钥生成...", action: #selector(Acts.a9), keyEquivalent: "")
                m.addItem(withTitle: "打开.ssh目录", action: #selector(Acts.a10), keyEquivalent: "")
                return m
            }
            MenuBtn("设置") {
                let m = NSMenu()
                m.addItem(withTitle: "偏好设置...", action: #selector(Acts.a11), keyEquivalent: "")
                return m
            }
            MenuBtn("帮助") {
                let m = NSMenu()
                m.addItem(withTitle: "关于", action: #selector(Acts.a12), keyEquivalent: "")
                return m
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                swBtn("plus", "新建会话") { sessionManager.showConnectionEditor = true }
                swBtn("terminal", "本地终端") { sessionManager.openLocalSession() }
                swBtn("arrow.triangle.2.circlepath", "SFTP") { showSFTP.toggle() }
                swBtn("wrench.and.screwdriver", "工具") { showNetworkTools = true }
            }.padding(.trailing, 10)
        }
        .frame(height: 36)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { Acts.shared.setup(sessionManager, sftp: $showSFTP, tools: $showNetworkTools, settings: $showSettings) }
    }
    
    func swBtn(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(title).font(.system(size: 12))
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.1)))
        }.buttonStyle(.plain)
    }
}

// MARK: - 原生 NSButton 菜单
struct MenuBtn: NSViewRepresentable {
    let title: String
    let menuBuilder: () -> NSMenu
    
    init(_ title: String, menuBuilder: @escaping () -> NSMenu) {
        self.title = title; self.menuBuilder = menuBuilder
    }
    
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let btn = NSButton(title: title, target: nil, action: nil)
        btn.bezelStyle = .texturedRounded
        btn.isBordered = false
        btn.font = .systemFont(ofSize: 13)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.target = context.coordinator
        btn.action = #selector(Coordinator.tap)
        
        container.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            btn.topAnchor.constraint(equalTo: container.topAnchor),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        
        // 设最小宽度，保证能点到
        let w = max(50, (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 13)]).width + 20)
        container.widthAnchor.constraint(greaterThanOrEqualToConstant: w).isActive = true
        
        return container
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(builder: menuBuilder) }
    
    class Coordinator: NSObject {
        let builder: () -> NSMenu
        init(builder: @escaping () -> NSMenu) { self.builder = builder }
        
        @objc func tap(_ sender: NSButton) {
            let menu = builder()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height), in: sender)
        }
    }
}

// MARK: - 全局动作
class Acts: NSObject {
    static let shared = Acts()
    var sm: SessionManager!
    var sftp: Binding<Bool>!, tools: Binding<Bool>!, settings: Binding<Bool>!
    
    func setup(_ sm: SessionManager, sftp: Binding<Bool>, tools: Binding<Bool>, settings: Binding<Bool>) {
        self.sm = sm; self.sftp = sftp; self.tools = tools; self.settings = settings
    }
    
    @objc func a1() { sm.openLocalSession() }
    @objc func a2() { sm.showConnectionEditor = true }
    @objc func a3() { if let id = sm.selectedSessionId { sm.closeSession(id) } }
    @objc func a4() { sm.closeAllSessions() }
    @objc func a5() {
        let p = NSOpenPanel(); p.allowedContentTypes = [.json]
        if p.runModal() == .OK, let u = p.url, let d = try? Data(contentsOf: u),
           let f = try? JSONDecoder().decode([ConnectionFolder].self, from: d) { sm.importFolders(f) }
    }
    @objc func a6() {
        let p = NSSavePanel(); p.allowedContentTypes = [.json]; p.nameFieldStringValue = "会话.json"
        if p.runModal() == .OK, let u = p.url, let d = try? JSONEncoder().encode(sm.folders) { try? d.write(to: u) }
    }
    @objc func a7() { sftp.wrappedValue.toggle() }
    @objc func a8() { tools.wrappedValue = true }
    @objc func a9() {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        p.arguments = ["-t","rsa","-b","4096","-f",NSHomeDirectory()+"/.ssh/id_rsa_mac终端助手","-N",""]; try? p.run()
    }
    @objc func a10() { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")) }
    @objc func a11() { settings.wrappedValue = true }
    @objc func a12() { }
}
