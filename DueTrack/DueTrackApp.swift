import SwiftUI
import UserNotifications
import CoreData

@main
struct DueTrackApp: App {
    let persistenceController = CoreDataManager.shared
    
    init() {
        // Capture persistenceController before Task to avoid escaping closure error
        let coreDataManager = CoreDataManager.shared
        
        // Request notification permissions on app launch
        Task {
            let authorized = await NotificationManager.shared.requestAuthorization()
            if authorized {
                // Reschedule all notifications for existing bills
                let context = coreDataManager.viewContext
                let request: NSFetchRequest<Bill> = Bill.fetchRequest()
                request.predicate = NSPredicate(format: "isActive == YES")
                
                do {
                    let bills = try context.fetch(request)
                    await MainActor.run {
                        NotificationManager.shared.rescheduleAllNotifications(for: bills)
                    }
                } catch {
                    print("Error fetching bills for notification rescheduling: \(error)")
                }
            }
        }
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}

struct ContentView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showOnboarding: Bool = {
        // Check if onboarding has been completed on first launch
        return !OnboardingManager.shared.hasCompletedOnboarding
    }()
    
    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
                    .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                    .zIndex(1)
            } else {
                MainTabView()
                    .transition(.opacity)
                    .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
                    .zIndex(0)
            }
        }
        .animation(.easeInOut, value: showOnboarding)
        .onAppear {
            // Double-check onboarding status on appear (in case it changed)
            let shouldShow = !OnboardingManager.shared.hasCompletedOnboarding
            if showOnboarding != shouldShow {
                showOnboarding = shouldShow
            }
        }
    }
}

// MARK: - Notification Delegate
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap if needed
        completionHandler()
    }
}

