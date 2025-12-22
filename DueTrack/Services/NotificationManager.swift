import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            await MainActor.run {
                checkAuthorizationStatus()
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    // MARK: - Schedule Notifications
    func scheduleBillReminder(for bill: Bill, daysBefore: [Int]) {
        // Check authorization first
        guard authorizationStatus == .authorized else {
            print("Notification authorization not granted. Cannot schedule reminders.")
            return
        }
        
        let nextDueDate = bill.nextDueDate
        let calendar = Calendar.current
        let now = Date()
        
        guard let billId = bill.id else {
            print("Warning: Bill has no id; skipping notifications.")
            return
        }
        
        for days in daysBefore {
            guard let reminderDay = calendar.date(byAdding: .day, value: -days, to: nextDueDate) else {
                continue
            }
            
            let content = UNMutableNotificationContent()
            content.title = "Bill Reminder: \(bill.name)"
            content.body = "$\(String(format: "%.2f", bill.amount)) is due in \(days) day\(days == 1 ? "" : "s")"
            content.sound = .default
            content.badge = 1
            content.userInfo = [
                "billId": billId.uuidString,
                "type": "reminder"
            ]
            
            // Schedule notification at user's preferred time
            let settings = NotificationSettingsManager.shared
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: reminderDay)
            dateComponents.hour = settings.notificationHour
            dateComponents.minute = settings.notificationMinute
            
            // Ensure the final trigger date/time is still in the future
            if let triggerDate = calendar.date(from: dateComponents),
               triggerDate <= now {
                continue
            }
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            let identifier = "\(billId.uuidString)-reminder-\(days)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
    
    func scheduleOverdueAlert(for bill: Bill) {
        // Check authorization first
        guard authorizationStatus == .authorized else {
            print("Notification authorization not granted. Cannot schedule overdue alert.")
            return
        }
        
        let nextDueDate = bill.nextDueDate
        let calendar = Calendar.current
        let now = Date()
        
        guard let alertDay = calendar.date(byAdding: .day, value: 1, to: nextDueDate) else {
            return
        }
        
        guard let billId = bill.id else {
            print("Warning: Bill has no id; skipping overdue notification.")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Overdue Bill: \(bill.name)"
        content.body = "$\(String(format: "%.2f", bill.amount)) was due yesterday and is now overdue"
        content.sound = .default
        content.badge = 1
        content.userInfo = [
            "billId": billId.uuidString,
            "type": "overdue"
        ]
        
        // Schedule overdue alert at user's preferred time
        let settings = NotificationSettingsManager.shared
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: alertDay)
        dateComponents.hour = settings.notificationHour
        dateComponents.minute = settings.notificationMinute
        
        // Ensure the final trigger date/time is still in the future
        if let triggerDate = calendar.date(from: dateComponents),
           triggerDate <= now {
            return
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let identifier = "\(billId.uuidString)-overdue"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling overdue notification: \(error)")
            }
        }
    }
    
    // MARK: - Cancel Notifications
    func cancelNotifications(for billId: UUID?) {
        guard let billId = billId else {
            print("NotificationManager: cancelNotifications called with nil billId, skipping.")
            return
        }
        
        let identifiers = [
            "\(billId.uuidString)-reminder-1",
            "\(billId.uuidString)-reminder-3",
            "\(billId.uuidString)-reminder-7",
            "\(billId.uuidString)-overdue"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Update Badge
    func updateBadgeCount(upcomingBillsCount: Int) {
        UNUserNotificationCenter.current().setBadgeCount(upcomingBillsCount)
    }
    
    // MARK: - Reschedule All Notifications
    func rescheduleAllNotifications(for bills: [Bill]) {
        guard authorizationStatus == .authorized else {
            print("Notification authorization not granted. Cannot reschedule notifications.")
            return
        }
        
        // Cancel all existing notifications first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Schedule notifications for all active bills
        for bill in bills where bill.isActive {
            scheduleBillReminder(for: bill, daysBefore: [1, 3, 7])
            scheduleOverdueAlert(for: bill)
        }
        
        print("Rescheduled notifications for \(bills.count) bills")
    }
    
    // MARK: - Test Notification
    func scheduleTestNotification() {
        guard authorizationStatus == .authorized else {
            print("Notification authorization not granted. Cannot schedule test notification.")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Test Notification"
        content.body = "This is a test notification from DueTrack. If you see this, notifications are working!"
        content.sound = .default
        content.badge = 1
        
        // Schedule for 5 seconds from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        
        let identifier = "test-notification-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling test notification: \(error)")
            } else {
                print("Test notification scheduled! It will appear in 5 seconds.")
            }
        }
    }
}

