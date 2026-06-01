import SwiftUI

struct NetworkToolsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTool = 0
    @State private var targetHost: String = ""
    @State private var output: String = ""
    @State private var isRunning: Bool = false
    
    let tools = [
        (icon: "wifi", name: "Ping测试", desc: "测试网络连通性", placeholder: "如 google.com"),
        (icon: "point.3.connected.trianglepath.dotted", name: "路由追踪", desc: "追踪数据包路由", placeholder: "如 baidu.com"),
        (icon: "globe", name: "DNS查询", desc: "查询域名解析", placeholder: "如 example.com"),
        (icon: "server.rack", name: "端口扫描", desc: "扫描常见端口", placeholder: "如 192.168.1.1"),
        (icon: "info.circle", name: "Whois查询", desc: "查询域名信息", placeholder: "如 github.com"),
        (icon: "network", name: "网络信息", desc: "本机网络接口", placeholder: "无需输入"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("网络工具箱", systemImage: "wrench.and.screwdriver")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("关闭") { dismiss() }.keyboardShortcut(.escape)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            
            Divider()
            
            HStack(spacing: 0) {
                // 左侧列表
                VStack(spacing: 2) {
                    ForEach(0..<tools.count, id: \.self) { i in
                        Button { selectedTool = i; output = "" } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tools[i].icon).font(.system(size: 18)).frame(width: 28)
                                    .foregroundColor(selectedTool == i ? .white : .blue)
                                Text(tools[i].name)
                                    .font(.system(size: 15, weight: selectedTool == i ? .semibold : .regular))
                                    .foregroundColor(selectedTool == i ? .white : .primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTool == i ? Color.accentColor : Color.clear))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(width: 180).padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // 右侧内容
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: tools[selectedTool].icon).font(.system(size: 20)).foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tools[selectedTool].name).font(.system(size: 16, weight: .bold))
                            Text(tools[selectedTool].desc).font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(spacing: 10) {
                        Text("目标:").font(.system(size: 14, weight: .medium))
                            .frame(width: 50, alignment: .trailing)
                        TextField(tools[selectedTool].placeholder, text: $targetHost)
                            .textFieldStyle(.roundedBorder).font(.system(size: 14))
                            .frame(maxWidth: .infinity).onSubmit { runTool() }
                        Button { runTool() } label: {
                            HStack(spacing: 4) {
                                if isRunning { ProgressView().controlSize(.small) }
                                else { Image(systemName: "play.fill") }
                                Text(isRunning ? "执行中..." : "执行")
                            }.frame(width: 90)
                        }
                        .disabled(isRunning || (selectedTool != 5 && targetHost.isEmpty))
                        .buttonStyle(.borderedProminent)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("输出结果").font(.system(size: 13, weight: .medium))
                            Spacer()
                            if !output.isEmpty {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(output, forType: .string)
                                } label: {
                                    Label("复制", systemImage: "doc.on.doc").font(.system(size: 11))
                                }.buttonStyle(.plain)
                            }
                        }
                        ScrollView {
                            Text(output.isEmpty ? "点击「执行」开始运行..." : output).foregroundColor(.white)
                                .font(.system(size: 13, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).textSelection(.enabled)
                        }
                        .frame(minHeight: 200)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black))
                    }
                }.padding(20)
            }
        }
        .frame(width: 720, height: 480)
    }
    
    private func runTool() {
        isRunning = true; output = ""
        DispatchQueue.global().async {
            let result: String
            switch selectedTool {
            case 0: result = runCmd("/sbin/ping", ["-c", "4", targetHost], timeout: 12)
            case 1: result = runCmd("/usr/sbin/traceroute", ["-m", "15", targetHost], timeout: 30)
            case 2: result = runCmd("/usr/bin/nslookup", [targetHost], timeout: 10)
            case 3: result = scanPorts(host: targetHost)
            case 4: result = runCmd("/usr/bin/whois", [targetHost], timeout: 15)
            case 5: result = runCmd("/sbin/ifconfig", [], timeout: 10)
            default: result = "未知工具"
            }
            DispatchQueue.main.async { output = result; isRunning = false }
        }
    }
    
    private func runCmd(_ path: String, _ args: [String], timeout: TimeInterval) -> String {
        let result = CommandRunner.run(path, args, timeout: timeout)
        return result.output
    }
    
    private func scanPorts(host: String) -> String {
        var r = "端口扫描 \(host):\n"
        r += String(format: "%-8s %s\n", "端口", "状态")
        r += String(repeating: "-", count: 20) + "\n"
        for port in [21, 22, 23, 25, 53, 80, 110, 143, 443, 445, 993, 995, 3306, 3389, 5432, 8080] {
            let result = CommandRunner.run("/usr/bin/nc", ["-z", "-w", "1", host, "\(port)"], timeout: 2)
            r += String(format: "%-8d %s\n", port, result.succeeded ? "开放" : "关闭")
        }
        return r
    }
}
