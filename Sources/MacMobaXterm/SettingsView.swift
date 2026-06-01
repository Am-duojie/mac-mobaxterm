import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("terminalFontSize") private var fontSize: Double = 14
    @AppStorage("defaultPort") private var defaultPort: Int = 22
    @AppStorage("connectTimeout") private var connectTimeout: Int = 10
    @AppStorage("keepAliveInterval") private var keepAlive: Int = 60
    @AppStorage("strictHostKey") private var strictHostKey: Bool = false
    @AppStorage("defaultAuthMethod") private var defaultAuth: String = "password"
    @AppStorage("showConnectionStatusBar") private var showConnectionStatusBar: Bool = true
    @AppStorage("terminalWrapLines") private var terminalWrapLines: Bool = true
    @AppStorage("terminalTrueColor") private var terminalTrueColor: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("偏好设置").font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }
            .padding()
            
            Divider()
            
            TabView {
                // 终端设置
                Form {
                    Section("字体") {
                        HStack {
                            Text("字体大小")
                            Spacer()
                            Stepper("\(Int(fontSize))pt", value: $fontSize, in: 10...24)
                                .frame(width: 130)
                        }
                    }
                    
                    Section("显示") {
                        Toggle("显示连接状态栏", isOn: $showConnectionStatusBar)
                        Toggle("终端自动换行", isOn: $terminalWrapLines)
                        Toggle("使用真彩色", isOn: $terminalTrueColor)
                    }
                }
                .tabItem { Label("终端", systemImage: "terminal") }
                .padding()
                
                // SSH设置
                Form {
                    Section("连接") {
                        HStack {
                            Text("默认端口")
                            Spacer()
                            TextField("", value: $defaultPort, format: .number)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("连接超时(秒)")
                            Spacer()
                            Stepper("\(connectTimeout)s", value: $connectTimeout, in: 5...60, step: 5)
                                .frame(width: 130)
                        }
                        HStack {
                            Text("KeepAlive(秒)")
                            Spacer()
                            Stepper("\(keepAlive)s", value: $keepAlive, in: 0...300, step: 10)
                                .frame(width: 130)
                        }
                        Toggle("严格主机密钥检查", isOn: $strictHostKey)
                    }
                    
                    Section("默认认证") {
                        Picker("认证方式", selection: $defaultAuth) {
                            Text("密码").tag("password")
                            Text("SSH密钥").tag("key")
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .tabItem { Label("SSH", systemImage: "network") }
                .padding()
                
                // 关于
                VStack(spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    Text("Mac终端助手")
                        .font(.title2.bold())
                    Text("版本 1.0.0")
                        .foregroundStyle(.secondary)
                    Text("你的macOS远程计算工具箱")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("对标MobaXterm，为macOS打造")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                .tabItem { Label("关于", systemImage: "info.circle") }
                .padding()
            }
        }
        .frame(width: 500, height: 380)
    }
}
