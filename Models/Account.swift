import Foundation

public struct AccountSettings: Codable {
    public var refreshInterval: TimeInterval
    public var alertThresholds: AlertThresholds
    public var predictionsEnabled: Bool
    public var notificationsEnabled: Bool
    public var theme: Theme
    public var defaultView: DefaultView

    public init(
        refreshInterval: TimeInterval = 30,
        alertThresholds: AlertThresholds = AlertThresholds(),
        predictionsEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        theme: Theme = .auto,
        defaultView: DefaultView = .tachometer
    ) {
        self.refreshInterval = refreshInterval
        self.alertThresholds = alertThresholds
        self.predictionsEnabled = predictionsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.theme = theme
        self.defaultView = defaultView
    }
}

public struct AlertThresholds: Codable {
    public var warning: Double
    public var critical: Double

    public init(warning: Double = 0.75, critical: Double = 0.90) {
        self.warning = warning
        self.critical = critical
    }
}

public enum Theme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case auto = "auto"

    public var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .auto:
            return "System"
        }
    }
}

public enum DefaultView: String, Codable, CaseIterable {
    case tachometer = "tachometer"
    case graph = "graph"
    case dashboard = "dashboard"

    public var displayName: String {
        switch self {
        case .tachometer:
            return "Tachometer"
        case .graph:
            return "Graph"
        case .dashboard:
            return "Dashboard"
        }
    }
}
