import Foundation
import TodoDomain
import Security

public protocol TokenStore: Sendable {
    func load() throws -> SessionTokens?
    func save(_ tokens: SessionTokens) throws
    func clear() throws
}

/// One Keychain item for the whole pair: rotating tokens are always written atomically.
public struct KeychainTokenStore: TokenStore {
    private let service: String
    public init(service: String = "com.pelypets.todolist.native.session") { self.service = service }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "session"]
    }

    public func load() throws -> SessionTokens? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let tokens = try? JSONDecoder().decode(SessionTokens.self, from: data) else {
            throw AppError.secureStorage
        }
        return tokens
    }

    public func save(_ tokens: SessionTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let values = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, values as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw AppError.secureStorage }
        } else if status != errSecSuccess {
            throw AppError.secureStorage
        }
    }

    public func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AppError.secureStorage }
    }
}
