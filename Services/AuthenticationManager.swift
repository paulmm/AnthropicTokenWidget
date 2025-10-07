import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
public class AuthenticationManager: NSObject, ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var currentAccount: Account?
    @Published public var accounts: [Account] = []
    @Published public var isAuthenticating = false
    @Published public var authError: Error?
    
    private let keychainManager = KeychainManager.shared
    private var authSession: ASWebAuthenticationSession?
    
    public override init() {
        super.init()
        loadAccounts()
    }
    
    public func authenticate(presentationContext: ASWebAuthenticationPresentationContextProviding) async throws {
        isAuthenticating = true
        authError = nil
        
        defer {
            isAuthenticating = false
        }
        
        let authURL = URL(string: "https://console.anthropic.com/oauth/authorize")!
        let callbackScheme = "anthropic-token-widget"
        
        return try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                if let error = error {
                    self?.authError = error
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    let error = NSError(domain: "AuthenticationManager", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "No callback URL received"
                    ])
                    self?.authError = error
                    continuation.resume(throwing: error)
                    return
                }
                
                self?.handleCallback(callbackURL) { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        self?.authError = error
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            authSession?.presentationContextProvider = presentationContext
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }
    }
    
    private func handleCallback(_ url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              let email = components.queryItems?.first(where: { $0.name == "email" })?.value else {
            completion(.failure(NSError(domain: "AuthenticationManager", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid callback URL format"
            ])))
            return
        }
        
        Task { @MainActor in
            do {
                let tierString = components.queryItems?.first(where: { $0.name == "tier" })?.value ?? "free"
                let tier = AccountTier(rawValue: tierString) ?? .free
                
                let account = Account(
                    email: email,
                    apiKey: token,
                    tier: tier
                )
                
                try await addAccount(account)
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    public func authenticateWithAPIKey(_ apiKey: String, email: String) async throws {
        // Note: This is a demo app. Anthropic doesn't provide real-time usage tracking APIs.
        // We'll accept any API key format and show mock data.

        guard apiKey.hasPrefix("sk-ant-") else {
            throw NSError(domain: "AuthenticationManager", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "API key must start with 'sk-ant-'"
            ])
        }

        guard apiKey.count > 20 else {
            throw NSError(domain: "AuthenticationManager", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "API key appears to be too short"
            ])
        }

        // Create account with tier2 as default for demo
        let account = Account(
            email: email,
            apiKey: apiKey,
            tier: .tier2
        )

        try await addAccount(account)
    }
    
    public func addAccount(_ account: Account) async throws {
        try keychainManager.saveAccount(account)
        
        await MainActor.run {
            if !accounts.contains(where: { $0.id == account.id }) {
                accounts.append(account)
            }
            
            if currentAccount == nil {
                currentAccount = account
                isAuthenticated = true
            }
            
            saveAccountsList()
        }
    }
    
    public func switchAccount(to account: Account) {
        currentAccount = account
        isAuthenticated = true
        saveAccountsList()
    }
    
    public func removeAccount(_ account: Account) throws {
        try keychainManager.deleteAccount(account)
        
        accounts.removeAll { $0.id == account.id }
        
        if currentAccount?.id == account.id {
            currentAccount = accounts.first
            isAuthenticated = currentAccount != nil
        }
        
        saveAccountsList()
    }
    
    public func signOut() {
        currentAccount = nil
        isAuthenticated = false
        saveAccountsList()
    }
    
    public func signOutAll() throws {
        try keychainManager.clearAllData()
        accounts.removeAll()
        currentAccount = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "accountsList")
    }
    
    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: "accountsList"),
              let accountIDs = try? JSONDecoder().decode([UUID].self, from: data) else {
            return
        }
        
        accounts = accountIDs.compactMap { id in
            try? keychainManager.getAccount(id: id)
        }
        
        if let lastUsedID = UserDefaults.standard.string(forKey: "lastUsedAccountID"),
           let uuid = UUID(uuidString: lastUsedID),
           let account = accounts.first(where: { $0.id == uuid }) {
            currentAccount = account
            isAuthenticated = true
        } else if let firstAccount = accounts.first {
            currentAccount = firstAccount
            isAuthenticated = true
        }
    }
    
    private func saveAccountsList() {
        let accountIDs = accounts.map { $0.id }
        if let data = try? JSONEncoder().encode(accountIDs) {
            UserDefaults.standard.set(data, forKey: "accountsList")
        }
        
        if let currentAccount = currentAccount {
            UserDefaults.standard.set(currentAccount.id.uuidString, forKey: "lastUsedAccountID")
        }
    }
}