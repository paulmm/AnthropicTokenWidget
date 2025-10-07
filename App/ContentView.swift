import SwiftUI

struct ContentView: View {
    @StateObject private var tokenMonitor = TokenUsageMonitor.shared
    @State private var selectedTab = 0
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        if isLoading {
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Loading Claude Code usage data...")
                    .font(.headline)
                    .foregroundColor(.secondary)

                if let error = loadError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await loadClaudeCodeData()
            }
        } else {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "gauge")
                    }
                    .tag(0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                PredictionsView()
                    .tabItem {
                        Label("Predictions", systemImage: "wand.and.stars")
                    }
                    .tag(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(tokenMonitor)
        }
    }

    private func loadClaudeCodeData() async {
        do {
            try await tokenMonitor.loadClaudeCodeData()
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                loadError = error.localizedDescription
                // Still show UI even if there's an error
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isLoading = false
                }
            }
        }
    }
}