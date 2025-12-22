import SwiftUI
import UserNotifications

struct NotificationDebugView: View {
    @State private var scheduledNotifications: [UNNotificationRequest] = []
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    var body: some View {
        List {
            Section(header: Text("Notification Status")) {
                HStack {
                    Text("Authorization")
                    Spacer()
                    Text(statusText)
                        .foregroundColor(statusColor)
                }
                
                Button("Request Permission") {
                    Task {
                        await requestPermission()
                    }
                }
            }
            
            Section(header: Text("Scheduled Notifications (\(scheduledNotifications.count))")) {
                if scheduledNotifications.isEmpty {
                    Text("No notifications scheduled")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(scheduledNotifications, id: \.identifier) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(request.content.title)
                                .font(.headline)
                            Text(request.content.body)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                                Text("Scheduled: \(formatDateComponents(trigger.dateComponents))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("ID: \(request.identifier)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Button("Refresh List") {
                    loadScheduledNotifications()
                }
                
                Button("Clear All Notifications", role: .destructive) {
                    clearAllNotifications()
                }
            }
        }
        .navigationTitle("Notification Debug")
        .onAppear {
            checkAuthorization()
            loadScheduledNotifications()
        }
    }
    
    private var statusText: String {
        switch authorizationStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }
    
    private var statusColor: Color {
        switch authorizationStatus {
        case .authorized: return .green
        case .denied: return .red
        default: return .orange
        }
    }
    
    private func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    private func requestPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                checkAuthorization()
            }
        } catch {
            print("Error requesting notification permission: \(error)")
            await MainActor.run {
                checkAuthorization()
            }
        }
    }
    
    private func loadScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.scheduledNotifications = requests.sorted { $0.identifier < $1.identifier }
            }
        }
    }
    
    private func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        loadScheduledNotifications()
    }
    
    private func formatDateComponents(_ components: DateComponents) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        
        var parts: [String] = []
        if let year = components.year { parts.append("\(year)") }
        if let month = components.month { parts.append("\(month)") }
        if let day = components.day { parts.append("\(day)") }
        if let hour = components.hour { parts.append("\(hour):00") }
        
        return parts.joined(separator: "/")
    }
}

