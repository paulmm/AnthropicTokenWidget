import Foundation
import UserNotifications
import SwiftUI

@MainActor
public class NotificationManager: NSObject, ObservableObject {
    public static let shared = NotificationManager()
    
    @Published public var hasPermission = false
    @Published public var pendingNotifications: [UNNotificationRequest] = []
    
    private override init() {
        super.init()
        checkPermission()
    }
    
    public func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            
            await MainActor.run {
                self.hasPermission = granted
            }
            
            if granted {
                await registerCategories()
            }
            
            return granted
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }
    
    private func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func registerCategories() async {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View Dashboard",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: .destructive
        )
        
        let usageCategory = UNNotificationCategory(
            identifier: "USAGE_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([usageCategory])
    }
    
    public func sendWarningAlert(usage: TokenUsage) {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Token Usage Warning"
        content.body = "You've used \(Int(usage.percentageUsed * 100))% of your tokens. \(usage.tokensRemaining) tokens remaining."
        content.sound = .default
        content.badge = NSNumber(value: Int(usage.percentageUsed * 100))
        content.categoryIdentifier = "USAGE_ALERT"
        
        content.userInfo = [
            "type": "warning",
            "tokensUsed": usage.tokensUsed,
            "maxTokens": usage.maxTokens
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send warning notification: \(error)")
            }
        }
    }
    
    public func sendCriticalAlert(usage: TokenUsage) {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Critical Token Usage"
        content.body = "URGENT: \(Int(usage.percentageUsed * 100))% used! Only \(usage.tokensRemaining) tokens left."
        content.sound = .defaultCritical
        content.badge = NSNumber(value: Int(usage.percentageUsed * 100))
        content.categoryIdentifier = "USAGE_ALERT"
        content.interruptionLevel = .critical
        
        content.userInfo = [
            "type": "critical",
            "tokensUsed": usage.tokensUsed,
            "maxTokens": usage.maxTokens
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "critical_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send critical notification: \(error)")
            }
        }
    }
    
    public func sendPredictionAlert(prediction: Prediction) {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Token Usage Prediction"
        content.body = prediction.recommendation
        content.sound = .default
        content.categoryIdentifier = "USAGE_ALERT"
        
        if let timeToLimit = prediction.timeToLimit, timeToLimit < 3600 {
            content.subtitle = "Limit in \(prediction.timeToLimitFormatted)"
            content.interruptionLevel = .timeSensitive
        }
        
        content.userInfo = [
            "type": "prediction",
            "projectedUsage": prediction.projectedUsage,
            "confidence": prediction.confidence
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "prediction_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send prediction notification: \(error)")
            }
        }
    }
    
    public func sendWindowResetNotification() {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Token Window Reset"
        content.body = "Your 5-hour token window has reset. Full quota available again!"
        content.sound = .default
        content.badge = 0
        
        content.userInfo = ["type": "reset"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reset_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send reset notification: \(error)")
            }
        }
    }
    
    public func scheduleWindowResetNotification(at date: Date) {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Token Window Will Reset Soon"
        content.body = "Your token window resets in 5 minutes. Get ready for a fresh quota!"
        content.sound = .default
        
        let triggerDate = date.addingTimeInterval(-300)
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "scheduled_reset",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule reset notification: \(error)")
            }
        }
    }
    
    public func getPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        await MainActor.run {
            self.pendingNotifications = requests
        }
    }
    
    public func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    public func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }
    
    public func updateBadge(to count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error = error {
                print("Failed to update badge: \(error)")
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "VIEW_ACTION":
            NotificationCenter.default.post(name: .openDashboard, object: nil)
        case UNNotificationDefaultActionIdentifier:
            NotificationCenter.default.post(name: .openDashboard, object: nil)
        default:
            break
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let openDashboard = Notification.Name("openDashboard")
}