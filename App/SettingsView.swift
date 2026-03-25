import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tokenMonitor: TokenUsageMonitor
    @AppStorage("accountTier") private var accountTier: String = "custom"
    @AppStorage("refreshInterval") private var refreshInterval: Double = 15
    @AppStorage("warningThreshold") private var warningThreshold: Double = 0.75
    @AppStorage("criticalThreshold") private var criticalThreshold: Double = 0.90
    @AppStorage("predictionsEnabled") private var predictionsEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("theme") private var theme: Theme = .auto
    @State private var showingDataExport = false
    @State private var showingClearDataAlert = false

    private var selectedTier: AccountTier {
        AccountTier(rawValue: accountTier) ?? .custom
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.largeTitle.bold())
                Spacer()
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 24) {
                    accountSection
                    refreshSection
                    alertsSection
                    featuresSection
                    appearanceSection
                    dataSection
                    aboutSection
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingDataExport) {
            DataExportView()
        }
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will remove all stored data including usage history and patterns. This action cannot be undone.")
        }
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Tier")
                            .font(.subheadline.bold())
                        Text("Set your Anthropic API tier for accurate limits")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Picker("Plan", selection: $accountTier) {
                        ForEach(AccountTier.allCases, id: \.rawValue) { tier in
                            Text(tier.displayName).tag(tier.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: accountTier) { _ in
                        // Trigger data refresh with new tier
                        Task {
                            await tokenMonitor.refreshUsage()
                        }
                    }

                    Text(selectedTier.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if selectedTier == .custom {
                        if let limit = tokenMonitor.currentUsage?.maxTokens {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Detected limit: \(limit.formatted()) tokens/5h")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data Source")
                            .font(.subheadline.bold())
                        Text("~/.claude/projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                if let lastUpdated = tokenMonitor.usageHistory.last?.timestamp {
                    Divider()

                    HStack {
                        Text("Last Updated")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(lastUpdated.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                    }
                }

                if tokenMonitor.usageHistory.count > 0 {
                    HStack {
                        Text("Total Sessions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(tokenMonitor.usageHistory.count)")
                            .font(.subheadline.bold())
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var refreshSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refresh Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Refresh Interval")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(refreshInterval)) seconds")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                    }

                    Slider(value: $refreshInterval, in: 10...120, step: 5)
                        .onChange(of: refreshInterval) { _ in
                            // Restart monitoring with new interval
                            Task { @MainActor in
                                tokenMonitor.stopMonitoring()
                                tokenMonitor.startMonitoring()
                            }
                        }

                    Text("Real-time updates every \(Int(refreshInterval)) seconds (recommended: 10-20s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alert Thresholds")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Warning Alert", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                        Spacer()
                        Text("\(Int(warningThreshold * 100))%")
                            .font(.subheadline.bold())
                            .foregroundColor(.orange)
                    }
                    Slider(value: $warningThreshold, in: 0.5...0.9, step: 0.05)
                        .tint(.orange)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Critical Alert", systemImage: "exclamationmark.octagon.fill")
                            .font(.subheadline)
                            .foregroundColor(.red)
                        Spacer()
                        Text("\(Int(criticalThreshold * 100))%")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                    }
                    Slider(value: $criticalThreshold, in: 0.7...0.95, step: 0.05)
                        .tint(.red)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features")
                .font(.headline)

            VStack(spacing: 0) {
                SettingsToggleRow(
                    title: "Enable Predictions",
                    description: "Show AI-powered usage predictions and insights",
                    icon: "wand.and.stars",
                    isOn: $predictionsEnabled
                )

                Divider().padding(.leading, 44)

                SettingsToggleRow(
                    title: "Enable Notifications",
                    description: "Get alerts when approaching usage limits",
                    icon: "bell.fill",
                    isOn: $notificationsEnabled
                )
                .onChange(of: notificationsEnabled) { enabled in
                    if enabled {
                        Task {
                            await NotificationManager.shared.requestPermission()
                        }
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Theme")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Picker("Theme", selection: $theme) {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Management")
                .font(.headline)

            VStack(spacing: 0) {
                Button(action: { showingDataExport = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 24)
                        Text("Export Usage Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                    .padding()
                }
                .buttonStyle(.plain)

                Divider()

                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .frame(width: 24)
                    Text("History Retention")
                    Spacer()
                    Text("30 days")
                        .foregroundColor(.secondary)
                }
                .padding()

                Divider()

                Button(role: .destructive, action: { showingClearDataAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                            .frame(width: 24)
                        Text("Clear All Data")
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "info.circle")
                        .frame(width: 24)
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                .padding()

                Divider()

                Link(destination: URL(string: "https://github.com/paulmm/AnthropicTokenWidget")!) {
                    HStack {
                        Image(systemName: "book")
                            .frame(width: 24)
                        Text("Documentation")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                    .padding()
                }
                .buttonStyle(.plain)

                Divider()

                Link(destination: URL(string: "https://github.com/paulmm/AnthropicTokenWidget/issues")!) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble")
                            .frame(width: 24)
                        Text("Report Issue")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.primary)
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private func clearAllData() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        NotificationManager.shared.cancelAllNotifications()
        // Note: This only clears app settings, not the Claude Code data files
    }
}

struct DataExportView: View {
    @EnvironmentObject var tokenMonitor: TokenUsageMonitor
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ExportFormat = .csv
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Usage Data")
                .font(.largeTitle)
                .padding()

            Picker("Format", selection: $selectedFormat) {
                Text("CSV").tag(ExportFormat.csv)
                Text("JSON").tag(ExportFormat.json)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            if let url = exportURL {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)

                    Text("Export Ready")
                        .font(.headline)

                    Text(url.lastPathComponent)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Share") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }

            Spacer()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Export") {
                    exportData()
                }
                .buttonStyle(.borderedProminent)
                .disabled(exportURL != nil)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func exportData() {
        exportURL = tokenMonitor.exportData(format: selectedFormat)
    }
}

struct ShareSheet: NSViewControllerRepresentable {
    let items: [Any]

    func makeNSViewController(context: Context) -> NSViewController {
        let controller = NSViewController()
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: controller.view, preferredEdge: .minY)
        return controller
    }

    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}

struct SettingsToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .padding(.vertical, 8)
    }
}