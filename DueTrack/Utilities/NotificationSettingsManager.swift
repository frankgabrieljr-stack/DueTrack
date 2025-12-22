import Foundation

class NotificationSettingsManager {
    static let shared = NotificationSettingsManager()
    
    private let notificationHourKey = "notificationHour"
    private let notificationMinuteKey = "notificationMinute"
    
    private init() {}
    
    var notificationHour: Int {
        get {
            let hour = UserDefaults.standard.integer(forKey: notificationHourKey)
            return hour == 0 ? 9 : hour // Default to 9 AM
        }
        set {
            UserDefaults.standard.set(newValue, forKey: notificationHourKey)
        }
    }
    
    var notificationMinute: Int {
        get {
            return UserDefaults.standard.integer(forKey: notificationMinuteKey) // Default to 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: notificationMinuteKey)
        }
    }
}

