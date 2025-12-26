import SwiftUI
import CoreData
import EventKit

struct SettingsView: View {
    @EnvironmentObject var notificationViewModel: NotificationViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showOnboarding = false
    @State private var showNotificationTimePicker = false
    @State private var selectedHour = NotificationSettingsManager.shared.notificationHour
    @State private var selectedMinute = NotificationSettingsManager.shared.notificationMinute
    
    var body: some View {
        NavigationView {
            List {
                // MARK: Appearance
                Section(header: Text("Appearance")) {
                    Toggle(isOn: $themeManager.isDarkMode) {
                        HStack {
                            Image(systemName: themeManager.isDarkMode ? "moon.fill" : "sun.max.fill")
                            Text("Dark Mode")
                        }
                    }
                    .onChange(of: themeManager.isDarkMode) { _ in
                        // Theme change handled automatically by SwiftUI
                    }
                }
                
                // MARK: Notifications
                Section(header: Text("Notifications")) {
                    HStack {
                        Text("Notifications")
                        Spacer()
                        if notificationViewModel.isAuthorized {
                            Text("Enabled")
                                .foregroundColor(.accentGreen)
                        } else {
                            Text("Disabled")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !notificationViewModel.isAuthorized {
                        Button("Enable Notifications") {
                            Task {
                                await notificationViewModel.requestAuthorization()
                            }
                        }
                    }
                    
                    Button(action: {
                        showNotificationTimePicker = true
                    }) {
                        HStack {
                            Image(systemName: "clock")
                            Text("Notification Time")
                            Spacer()
                            Text("\(selectedHour):\(String(format: "%02d", selectedMinute))")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(action: {
                        NotificationManager.shared.scheduleTestNotification()
                    }) {
                        HStack {
                            Image(systemName: "bell.badge")
                            Text("Send Test Notification")
                        }
                    }
                    
                    NavigationLink(destination: NotificationDebugView()) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Notification Debug")
                        }
                    }
                }
                
                // MARK: Calendar
                Section(header: Text("Calendar")) {
                    Toggle(isOn: Binding(
                        get: { CalendarSyncManager.isSyncEnabled },
                        set: { newValue in
                            // Update stored state immediately so the toggle UI moves
                            CalendarSyncManager.isSyncEnabled = newValue
                            
                            Task {
                                if newValue {
                                    // Best effort: ask for access / ensure calendar exists,
                                    // then sync. If access is denied, this will just no-op.
                                    _ = await CalendarSyncManager.requestAccessIfNeeded()
                                    await syncBillsToCalendar()
                                } else {
                                    CalendarSyncManager.clearCalendar()
                                }
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Sync bills to Calendar")
                        }
                    }
                }
                
                // MARK: Help
                Section(header: Text("Help")) {
                    Button(action: {
                        showOnboarding = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Show Onboarding Guide")
                        }
                    }
                }
                
                // MARK: About
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .sheet(isPresented: $showNotificationTimePicker) {
                NotificationTimePickerView(
                    selectedHour: $selectedHour,
                    selectedMinute: $selectedMinute,
                    isPresented: $showNotificationTimePicker
                )
            }
        }
    }
    
    // MARK: - Calendar Sync Helper
    
    private func syncBillsToCalendar() async {
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            let bills = try context.fetch(request)
            await CalendarSyncManager.syncAllBills(bills)
        } catch {
            print("SettingsView: failed to fetch bills for calendar sync: \(error)")
        }
    }
}

struct NotificationTimePickerView: View {
    @Binding var selectedHour: Int
    @Binding var selectedMinute: Int
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notification Time")) {
                    Picker("Hour", selection: $selectedHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text("\(hour)").tag(hour)
                        }
                    }
                    
                    Picker("Minute", selection: $selectedMinute) {
                        ForEach(0..<60, id: \.self) { minute in
                            Text("\(minute)").tag(minute)
                        }
                    }
                }
                
                Section {
                    Text("All notifications will be sent at \(selectedHour):\(String(format: "%02d", selectedMinute))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notification Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNotificationTime()
                    }
                }
            }
        }
    }
    
    private func saveNotificationTime() {
        let settings = NotificationSettingsManager.shared
        settings.notificationHour = selectedHour
        settings.notificationMinute = selectedMinute
        
        Task {
            let coreDataManager = CoreDataManager.shared
            let context = coreDataManager.viewContext
            let request: NSFetchRequest<Bill> = Bill.fetchRequest()
            request.predicate = NSPredicate(format: "isActive == YES")
            
            do {
                let bills = try context.fetch(request)
                NotificationManager.shared.rescheduleAllNotifications(for: bills)
            } catch {
                print("Error fetching bills for notification time update: \(error)")
            }
        }
        
        isPresented = false
    }
}
