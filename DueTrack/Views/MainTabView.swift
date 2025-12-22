import SwiftUI

struct MainTabView: View {
    @StateObject private var billViewModel = BillViewModel()
    @StateObject private var paymentViewModel = PaymentViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "calendar")
                }
                .environmentObject(billViewModel)
                .environmentObject(paymentViewModel)
            
            BillsListView()
                .tabItem {
                    Label("Bills", systemImage: "list.bullet")
                }
                .environmentObject(billViewModel)
                .environmentObject(paymentViewModel)
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .environmentObject(billViewModel)
                .environmentObject(paymentViewModel)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .environmentObject(notificationViewModel)
        }
        .accentColor(.primaryBlue)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onAppear {
            // Request notification permissions on first launch
            Task {
                await notificationViewModel.requestAuthorization()
            }
        }
    }
}

