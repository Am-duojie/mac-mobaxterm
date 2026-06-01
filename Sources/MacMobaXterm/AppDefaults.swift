import Foundation

enum AppDefaults {
    static func register() {
        UserDefaults.standard.register(defaults: [
            "terminalFontSize": 14.0,
            "defaultPort": 22,
            "connectTimeout": 10,
            "keepAliveInterval": 60,
            "strictHostKey": false,
            "defaultAuthMethod": AuthMethod.password.rawValue,
            "showConnectionStatusBar": true,
            "terminalWrapLines": true,
            "terminalTrueColor": true,
        ])
    }
}
