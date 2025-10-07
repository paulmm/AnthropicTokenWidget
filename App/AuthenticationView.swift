import SwiftUI
import AuthenticationServices

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var apiKey = ""
    @State private var email = ""
    @State private var showingManualEntry = false
    @State private var validationError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            
            Spacer()
            
            logoSection
            
            Spacer()
            
            if showingManualEntry {
                manualEntrySection
            } else {
                authOptionsSection
            }
            
            Spacer()
            
            footerSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "#0F172A"), Color(hex: "#1E293B")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Anthropic Token Monitor")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            
            Text("Track your API usage in real-time")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 60)
    }
    
    private var logoSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#3B82F6").opacity(0.3),
                            Color(hex: "#3B82F6").opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 20)
            
            Image(systemName: "gauge")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(color: Color(hex: "#3B82F6").opacity(0.5), radius: 20)
        }
    }
    
    private var authOptionsSection: some View {
        VStack(spacing: 16) {
            Button(action: { showingManualEntry = true }) {
                HStack {
                    Image(systemName: "key")
                    Text("Enter API Key")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: 300)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            if authManager.isAuthenticating {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
            }

            if let error = authManager.authError {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
    }
    
    private var manualEntrySection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("your@email.com", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                SecureField("sk-ant-...", text: $apiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
            }
            
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showingManualEntry = false
                    apiKey = ""
                    email = ""
                    validationError = nil
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Authenticate") {
                    authenticateWithAPIKey()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(apiKey.isEmpty || email.isEmpty)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Your API key is stored securely in the macOS Keychain")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            Link("Learn more about API keys", destination: URL(string: "https://console.anthropic.com/api")!)
                .font(.caption)
                .foregroundColor(Color(hex: "#3B82F6"))
        }
        .padding(.bottom, 40)
    }
    
    private func authenticateWithOAuth() {
        Task {
            do {
                try await authManager.authenticate(presentationContext: ASWebAuthenticationPresentationContext())
            } catch {
                print("OAuth authentication failed: \(error)")
            }
        }
    }
    
    private func authenticateWithAPIKey() {
        Task {
            do {
                try await authManager.authenticateWithAPIKey(apiKey, email: email)
                apiKey = ""
                email = ""
            } catch {
                validationError = error.localizedDescription
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#3B82F6"), Color(hex: "#2563EB")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

class ASWebAuthenticationPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}