# Setup Instructions for Xcode

## Option 1: Open as Swift Package (Recommended for Xcode 13+)

1. **Open Xcode**
2. **File → Open**
3. Navigate to: `/Users/paulmangiamele/Documents/Code/ClaudeGauge/AnthropicTokenWidget`
4. Select the `Package.swift` file
5. Click **Open**
6. Xcode will automatically resolve dependencies and create the project

## Option 2: Create New Xcode Project

If the Package.swift doesn't work, create a new project:

1. **Open Xcode**
2. **File → New → Project**
3. Choose:
   - Platform: **macOS**
   - Application: **App**
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Product Name: `AnthropicTokenWidget`

4. After creating, **delete** the default files in the project

5. **Drag and drop** these folders from Finder into Xcode:
   - `/Users/paulmangiamele/Documents/Code/ClaudeGauge/AnthropicTokenWidget/App`
   - `/Users/paulmangiamele/Documents/Code/ClaudeGauge/AnthropicTokenWidget/Models`
   - `/Users/paulmangiamele/Documents/Code/ClaudeGauge/AnthropicTokenWidget/Services`
   - `/Users/paulmangiamele/Documents/Code/ClaudeGauge/AnthropicTokenWidget/Widget`

6. When prompted:
   - ✅ Check "Copy items if needed"
   - ✅ Check "Create groups"
   - ✅ Add to target: AnthropicTokenWidget

## Option 3: Use Terminal

If you have Xcode installed, run:

```bash
cd /Users/paulmangiamele/Documents/Code/ClaudeGauge/AnthropicTokenWidget
open Package.swift
```

This will open the package directly in Xcode.

## After Opening in Xcode

### Configure the Project:

1. **Select the project** in the navigator (blue icon at top)

2. **Under "Signing & Capabilities":**
   - Team: Select your Apple Developer team
   - Bundle Identifier: Change to something unique like `com.yourname.anthropicwidget`
   - Signing Certificate: Automatic

3. **Under "Info":**
   - Deployment Target: macOS 13.0

4. **Add Widget Extension (if needed):**
   - File → New → Target
   - Choose: Widget Extension
   - Product Name: `TokenWidget`
   - Include Configuration Intent: Yes

### Build and Run:

1. Select scheme: **AnthropicTokenWidget** (or **My Mac** as destination)
2. Press **⌘+R** to build and run
3. Or press **⌘+B** to just build

### Troubleshooting:

**If you see "No such module" errors:**
- File → Add Package Dependencies
- Search for: `swift-algorithms`
- Add it to your project
- Repeat for: `swift-collections`

**If you see signing errors:**
- You may need to enroll in the Apple Developer Program
- Or use a personal team for local development

**If the project won't build:**
- Clean build folder: ⌘+Shift+K
- Delete derived data: ~/Library/Developer/Xcode/DerivedData
- Restart Xcode

## File Structure

Your project should have this structure in Xcode:

```
AnthropicTokenWidget
├── App/
│   ├── AnthropicTokenWidgetApp.swift (main app entry)
│   ├── ContentView.swift
│   ├── DashboardView.swift
│   ├── AuthenticationView.swift
│   ├── SettingsView.swift
│   ├── HistoryView.swift
│   ├── PredictionsView.swift
│   └── ExportOptionsView.swift
├── Models/
│   ├── TokenUsage.swift
│   ├── Account.swift
│   └── Prediction.swift
├── Services/
│   ├── AnthropicAPIService.swift
│   ├── KeychainManager.swift
│   ├── AuthenticationManager.swift
│   ├── TokenUsageMonitor.swift
│   ├── PredictionEngine.swift
│   └── NotificationManager.swift
└── Widget/
    ├── TachometerView.swift
    ├── UsageGraphView.swift
    ├── TokenWidgetBundle.swift
    └── WidgetProvider.swift
```

## Quick Test

To test if everything is working without API:

1. The app uses `MockAnthropicAPIService` by default
2. Run the app and you should see sample data
3. To use real API, update `TokenUsageMonitor.swift` line 19:
   ```swift
   // Change from:
   self.apiService = MockAnthropicAPIService()
   // To:
   self.apiService = AnthropicAPIService(apiKey: "your-api-key")
   ```

## Need Help?

- Check the README.md for more details
- All code is in `/Users/paulmangiamele/Documents/Code/ClaudeGauge/AnthropicTokenWidget`
- The mock service allows testing without an API key