import Foundation
import SwiftUI

enum TabType: String, Codable {
    case local, ssh, sftp, telnet, rdp, serial, ftp, vnc
}

class Session: Identifiable, ObservableObject {
    let id: UUID
    let type: TabType
    let connection: Connection?
    let createdAt: Date
    @Published var title: String
    @Published var icon: String
    @Published var isConnected: Bool = false
    @Published var statusMessage: String = ""
    
    init(type: TabType, connection: Connection? = nil) {
        self.id = UUID()
        self.type = type
        self.connection = connection
        self.createdAt = Date()
        switch type {
        case .local:
            self.title = "本地终端"; self.icon = "terminal"; self.statusMessage = "本地Shell"
        case .ssh:
            self.title = connection?.displayName ?? "SSH连接"; self.icon = "network"; self.statusMessage = "SSH会话"
        case .sftp:
            self.title = "SFTP: \(connection?.host ?? "")"; self.icon = "arrow.triangle.2.circlepath"; self.statusMessage = "SFTP会话"
        case .telnet:
            self.title = "Telnet: \(connection?.host ?? "")"; self.icon = "globe"; self.statusMessage = "Telnet会话"
        case .rdp:
            self.title = "RDP: \(connection?.host ?? "")"; self.icon = "display"; self.statusMessage = "远程桌面"
        case .serial:
            self.title = connection?.name ?? "串口"; self.icon = "cable.connector"; self.statusMessage = "串口会话"
        case .ftp:
            self.title = "FTP: \(connection?.host ?? "")"; self.icon = "folder"; self.statusMessage = "FTP会话"
        case .vnc:
            self.title = "VNC: \(connection?.host ?? "")"; self.icon = "macwindow"; self.statusMessage = "VNC远程"
        }
    }
}
