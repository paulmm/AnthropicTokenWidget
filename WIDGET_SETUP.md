# Widget Setup Instructions

## Convert to Xcode Project with Widget Extension

Since this is currently a Swift Package Manager project, you need to create an Xcode project to add a Widget Extension.

### Steps:

1. **Open Xcode**
2. **Create New Project**:
   - File → New → Project
   - macOS → App
   - Product Name: "AnthropicTokenWidget"
   - Interface: SwiftUI
   - Language: Swift
   - Uncheck "Use Core Data" and "Include Tests"

3. **Add Widget Extension**:
   - File → New → Target
   - macOS → Widget Extension
   - Product Name: "TokenUsageWidget"
   - Check "Include Configuration Intent" (optional)
   - Click Finish
   - Click "Activate" when asked about the scheme

4. **Copy Files**:
   - Copy all files from `App/` to the main app target
   - Copy `Widget/` files to the Widget Extension target
   - Copy `Models/` and `Services/` to both targets (add to both target memberships)

5. **Configure Widget**:
   - Open `Widget/TokenWidgetBundle.swift`
   - Make sure it looks like this:

```swift
import WidgetKit
import SwiftUI

@main
struct TokenUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        TokenUsageWidget()
    }
}

struct TokenUsageWidget: Widget {
    let kind: String = "TokenUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            TachometerView(usage: entry.usage, size: .systemMedium)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Token Usage")
        .description("Monitor your Claude Code token usage")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

6. **Build and Run**:
   - Select the Widget Extension scheme
   - Run (⌘R)
   - This will open the Widget simulator

7. **Add to Notification Center**:
   - Right-click on the menu bar date/time
   - Click "Edit Widgets"
   - Find "Token Usage" widget
   - Drag it to your widget area
   - Click "Done"

## Option 2: Script-Based Setup

Run this command to open the project in Xcode and configure manually:

```bash
open -a Xcode AnthropicTokenWidget.xcodeproj
```

If the xcodeproj doesn't exist, you'll need to create it using Option 1.

## Notes

- Widgets on macOS appear in the Notification Center (swipe left from right edge of screen with trackpad, or click date/time in menu bar)
- Widgets update on a timeline - they don't update in real-time
- The widget will use the same data source as the main app (~/.claude/projects)

## Troubleshooting

**Widget doesn't appear:**
- Make sure you built the Widget Extension target
- Check that the widget is signed with the same Team ID as the app
- Try restarting Xcode and rebuilding

**Widget shows "Unable to Load":**
- Check the widget's console logs in Xcode
- Verify file paths are accessible to the widget extension
- Widget extensions have limited permissions - they may need App Group entitlements to share data

**Data not updating:**
- Widgets have their own timeline and update schedule
- Check `DashboardProvider.swift` timeline policy
- Consider using App Groups to share data between app and widget
