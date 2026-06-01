import Foundation
import Security

struct ConnectionCredential: Codable, Equatable {
    var password: String = ""
    var passphrase: String = ""
}

enum CredentialStore {
    private static let service = "MacMobaXterm.ConnectionCredential"
    
    static func save(_ credential: ConnectionCredential, id: String) {
        guard !credential.password.isEmpty || !credential.passphrase.isEmpty else {
            delete(id: id)
            return
        }
        guard let data = try? JSONEncoder().encode(credential) else { return }
        delete(id: id)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func load(id: String) -> ConnectionCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(ConnectionCredential.self, from: data)
    }
    
    static func delete(id: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
