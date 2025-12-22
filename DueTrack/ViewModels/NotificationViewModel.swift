import Foundation
import UserNotifications
import Combine
import SwiftUI

class NotificationViewModel: ObservableObject {
    @Published var reminderDays: [Int] = [1, 3, 7]
    @Published var isAuthorized = false
    
    private let notificationManager = NotificationManager.shared
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        notificationManager.checkAuthorizationStatus()
        isAuthorized = notificationManager.authorizationStatus == .authorized
    }
    
    func requestAuthorization() async {
        let granted = await notificationManager.requestAuthorization()
        await MainActor.run {
            isAuthorized = granted
        }
    }
    
    func updateReminderDays(_ days: [Int]) {
        reminderDays = days
        // Reschedule all notifications with new days
        // This would require fetching all bills and rescheduling
    }
}

