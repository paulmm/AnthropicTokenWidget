import SwiftUI

@main
struct AnthropicTokenWidgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, idealWidth: 1200, minHeight: 700, idealHeight: 800)
        }
        .defaultSize(width: 1200, height: 800)
    }
}