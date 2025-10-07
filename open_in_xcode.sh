#!/bin/bash

# Script to create and open Xcode project for AnthropicTokenWidget

echo "Creating Xcode project for AnthropicTokenWidget..."

# Navigate to project directory
cd "$(dirname "$0")"

# Remove any existing Xcode project files
rm -rf *.xcodeproj
rm -rf .build
rm -rf .swiftpm

# Create a temporary simple Package.swift for generating the project
cat > Package_temp.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnthropicTokenWidget",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AnthropicTokenWidget",
            targets: ["AnthropicTokenWidget"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AnthropicTokenWidget",
            path: ".",
            sources: [
                "App/AnthropicTokenWidgetApp.swift",
                "App/ContentView.swift",
                "App/DashboardView.swift",
                "App/AuthenticationView.swift",
                "App/SettingsView.swift",
                "App/HistoryView.swift",
                "App/PredictionsView.swift",
                "App/ExportOptionsView.swift",
                "Models/TokenUsage.swift",
                "Models/Account.swift",
                "Models/Prediction.swift",
                "Services/AnthropicAPIService.swift",
                "Services/KeychainManager.swift",
                "Services/AuthenticationManager.swift",
                "Services/TokenUsageMonitor.swift",
                "Services/PredictionEngine.swift",
                "Services/NotificationManager.swift",
                "Widget/TachometerView.swift",
                "Widget/UsageGraphView.swift",
                "Widget/TokenWidgetBundle.swift",
                "Widget/WidgetProvider.swift"
            ]
        )
    ]
)
EOF

# Backup original Package.swift
mv Package.swift Package_original.swift 2>/dev/null

# Use temporary Package.swift
mv Package_temp.swift Package.swift

# Generate Xcode project
echo "Generating Xcode project..."
swift package generate-xcodeproj 2>/dev/null

# Restore original Package.swift
mv Package.swift Package_temp.swift
mv Package_original.swift Package.swift 2>/dev/null

# Open in Xcode
if [ -d "AnthropicTokenWidget.xcodeproj" ]; then
    echo "Opening in Xcode..."
    open AnthropicTokenWidget.xcodeproj
    echo "✅ Project opened in Xcode!"
    echo ""
    echo "⚠️  Important Setup Steps:"
    echo "1. Select the project in the navigator"
    echo "2. Go to 'Signing & Capabilities'"
    echo "3. Add your Development Team"
    echo "4. Change the Bundle Identifier if needed"
    echo "5. Build and Run (⌘+R)"
else
    echo "❌ Failed to create Xcode project"
    echo "Please try opening Xcode and creating a new macOS app project manually,"
    echo "then add the Swift files from this directory."
fi