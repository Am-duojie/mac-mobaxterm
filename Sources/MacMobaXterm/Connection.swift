import Foundation

enum AuthMethod: String, Codable, CaseIterable {
    case password
    case key
    case keyWithPassphrase
    
    var displayName: String {
        switch self {
        case .password: return "密码"
        case .key: return "SSH密钥"
        case .keyWithPassphrase: return "密钥+密码短语"
        }
    }
}

struct Connection: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: TabType = .ssh
    var name: String = ""
    var host: String = ""
    var port: Int = 22
    var username: String = ""
    var authMethod: AuthMethod = .password
    var password: String = ""
    var privateKeyPath: String = ""
    var passphrase: String = ""
    var credentialId: String = UUID().uuidString
    var remotePath: String = ""
    var colorTag: String = "blue"
    var isFavorite: Bool = false
    
    // 串口参数
    var serialPort: String = "/dev/tty.usbserial"
    var serialBaud: Int = 115200
    var serialDataBits: Int = 8      // 5, 6, 7, 8
    var serialStopBits: Int = 1      // 1, 2
    var serialParity: String = "N"   // N=无, O=奇, E=偶
    var serialFlowControl: String = "none" // none, hardware, software
    
    var displayName: String {
        if !name.isEmpty { return name }
        if type == .serial { return serialPort }
        return username.isEmpty ? host : "\(username)@\(host)"
    }
    
    var defaultPort: Int {
        switch type {
        case .ssh, .sftp: return 22
        case .telnet: return 23
        case .rdp: return 3389
        case .ftp: return 21
        case .vnc: return 5900
        case .serial: return serialBaud
        case .local: return 0
        }
    }
    
    var sshCommand: [String] {
        var args: [String] = []
        args += ["-p", "\(port)"]
        args += ["-o", "StrictHostKeyChecking=accept-new"]
        args += ["-o", "ConnectTimeout=10"]
        
        switch authMethod {
        case .key, .keyWithPassphrase:
            if !privateKeyPath.isEmpty {
                args += ["-i", privateKeyPath]
            }
        case .password:
            break
        }
        
        if !remotePath.isEmpty {
            args += ["-t", "cd \(remotePath) && exec $SHELL -l"]
        }
        
        let target = username.isEmpty ? host : "\(username)@\(host)"
        args.append(target)
        return args
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, name, host, port, username, authMethod, password, privateKeyPath, passphrase, credentialId, remotePath, colorTag, isFavorite
        case serialPort, serialBaud, serialDataBits, serialStopBits, serialParity, serialFlowControl
    }
    
    init() {}
    
    init(id: UUID = UUID(), type: TabType = .ssh, name: String = "", host: String = "", port: Int = 22, username: String = "", authMethod: AuthMethod = .password, password: String = "", privateKeyPath: String = "", passphrase: String = "", credentialId: String = UUID().uuidString, remotePath: String = "", colorTag: String = "blue", isFavorite: Bool = false, serialPort: String = "/dev/tty.usbserial", serialBaud: Int = 115200, serialDataBits: Int = 8, serialStopBits: Int = 1, serialParity: String = "N", serialFlowControl: String = "none") {
        self.id = id
        self.type = type
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.password = password
        self.privateKeyPath = privateKeyPath
        self.passphrase = passphrase
        self.credentialId = credentialId
        self.remotePath = remotePath
        self.colorTag = colorTag
        self.isFavorite = isFavorite
        self.serialPort = serialPort
        self.serialBaud = serialBaud
        self.serialDataBits = serialDataBits
        self.serialStopBits = serialStopBits
        self.serialParity = serialParity
        self.serialFlowControl = serialFlowControl
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try c.decodeIfPresent(TabType.self, forKey: .type) ?? .ssh
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? ""
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? type.defaultPort
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        authMethod = try c.decodeIfPresent(AuthMethod.self, forKey: .authMethod) ?? .password
        password = try c.decodeIfPresent(String.self, forKey: .password) ?? ""
        privateKeyPath = try c.decodeIfPresent(String.self, forKey: .privateKeyPath) ?? ""
        passphrase = try c.decodeIfPresent(String.self, forKey: .passphrase) ?? ""
        credentialId = try c.decodeIfPresent(String.self, forKey: .credentialId) ?? id.uuidString
        remotePath = try c.decodeIfPresent(String.self, forKey: .remotePath) ?? ""
        colorTag = try c.decodeIfPresent(String.self, forKey: .colorTag) ?? "blue"
        isFavorite = try c.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        serialPort = try c.decodeIfPresent(String.self, forKey: .serialPort) ?? (type == .serial ? host : "/dev/tty.usbserial")
        serialBaud = try c.decodeIfPresent(Int.self, forKey: .serialBaud) ?? (type == .serial ? port : 115200)
        serialDataBits = try c.decodeIfPresent(Int.self, forKey: .serialDataBits) ?? 8
        serialStopBits = try c.decodeIfPresent(Int.self, forKey: .serialStopBits) ?? 1
        serialParity = try c.decodeIfPresent(String.self, forKey: .serialParity) ?? "N"
        serialFlowControl = try c.decodeIfPresent(String.self, forKey: .serialFlowControl) ?? "none"
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(name, forKey: .name)
        try c.encode(host, forKey: .host)
        try c.encode(port, forKey: .port)
        try c.encode(username, forKey: .username)
        try c.encode(authMethod, forKey: .authMethod)
        try c.encode(privateKeyPath, forKey: .privateKeyPath)
        try c.encode(credentialId, forKey: .credentialId)
        try c.encode(remotePath, forKey: .remotePath)
        try c.encode(colorTag, forKey: .colorTag)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encode(serialPort, forKey: .serialPort)
        try c.encode(serialBaud, forKey: .serialBaud)
        try c.encode(serialDataBits, forKey: .serialDataBits)
        try c.encode(serialStopBits, forKey: .serialStopBits)
        try c.encode(serialParity, forKey: .serialParity)
        try c.encode(serialFlowControl, forKey: .serialFlowControl)
    }
}

extension TabType {
    var defaultPort: Int {
        switch self {
        case .ssh, .sftp: return 22
        case .telnet: return 23
        case .rdp: return 3389
        case .ftp: return 21
        case .vnc: return 5900
        case .serial: return 115200
        case .local: return 0
        }
    }
}

struct ConnectionFolder: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = "新建文件夹"
    var icon: String = "folder"
    var connections: [Connection] = []
    
    var sortedConnections: [Connection] {
        connections.sorted { $0.isFavorite && !$1.isFavorite }
    }
}
