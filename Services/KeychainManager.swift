import Foundation
import Security

public enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(status: OSStatus)
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Duplicate item exists in keychain"
        case .invalidData:
            return "Invalid data in keychain"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}

public class KeychainManager {
    public static let shared = KeychainManager()
    
    private let service = "com.anthropic.tokenwidget"
    private let accessGroup: String? = nil
    
    private init() {}
    
    public func saveAPIKey(_ apiKey: String, for account: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecDuplicateItem {
            try updateAPIKey(apiKey, for: account)
        } else if status != errSecSuccess {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func getAPIKey(for account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let data = dataTypeRef as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return apiKey
    }
    
    public func updateAPIKey(_ apiKey: String, for account: String) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func deleteAPIKey(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func getAllAccounts() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var items: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw KeychainError.unhandledError(status: status)
        }
        
        guard let itemsArray = items as? [[String: Any]] else {
            return []
        }
        
        return itemsArray.compactMap { $0[kSecAttrAccount as String] as? String }
    }
    
    public func clearAllData() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    public func saveAccount(_ account: Account) throws {
        let encoder = JSONEncoder()
        let accountData = try encoder.encode(account)
        
        guard let accountString = String(data: accountData, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        try saveAPIKey(account.apiKey, for: account.email)
        
        UserDefaults.standard.set(accountData, forKey: "account_\(account.id.uuidString)")
    }
    
    public func getAccount(id: UUID) throws -> Account? {
        guard let accountData = UserDefaults.standard.data(forKey: "account_\(id.uuidString)") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Account.self, from: accountData)
    }
    
    public func deleteAccount(_ account: Account) throws {
        try deleteAPIKey(for: account.email)
        UserDefaults.standard.removeObject(forKey: "account_\(account.id.uuidString)")
    }
}