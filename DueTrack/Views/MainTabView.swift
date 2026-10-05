import SwiftUI

struct MainTabView: View {
    @StateObject private var billViewModel = BillViewModel()
    @StateObject private var paymentViewModel = PaymentViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var deepLinks = DeepLinkRouter.shared

    @State private var selectedTab = 0
    @State private var deepLinkBill: Bill?

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "calendar")
                }
                .tag(0)
                .environmentObject(billViewModel)
                .environmentObject(paymentViewModel)

            BillsListView()
                .tabItem {
                    Label("Bills", systemImage: "list.bullet")
                }
                .tag(1)
                .environmentObject(billViewModel)
                .environmentObject(paymentViewModel)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)
                .environmentObject(billViewModel)
                .environmentObject(paymentViewModel)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
                .environmentObject(notificationViewModel)
        }
        .accentColor(.primaryBlue)
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
        .onAppear {
            Task {
                await notificationViewModel.requestAuthorization()
            }
            openPendingDeepLinkIfNeeded()
        }
        .onOpenURL { url in
            _ = deepLinks.handle(url)
        }
        .onChange(of: deepLinks.pendingBillID) { _ in
            openPendingDeepLinkIfNeeded()
        }
        .onChange(of: billViewModel.bills.count) { _ in
            openPendingDeepLinkIfNeeded()
        }
        .sheet(isPresented: Binding(
            get: { deepLinkBill != nil },
            set: { if !$0 { deepLinkBill = nil } }
        )) {
            if let bill = deepLinkBill {
                NavigationView {
                    BillDetailView(bill: bill)
                        .environmentObject(billViewModel)
                        .environmentObject(paymentViewModel)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    deepLinkBill = nil
                                }
                            }
                        }
                }
            }
        }
    }

    private func openPendingDeepLinkIfNeeded() {
        guard let billID = deepLinks.pendingBillID else { return }

        if billViewModel.bills.isEmpty {
            billViewModel.fetchBills()
        }

        guard let bill = billViewModel.bills.first(where: { $0.id == billID }) else {
            // Keep pending until bills finish loading.
            billViewModel.fetchBills()
            return
        }

        selectedTab = 1
        deepLinkBill = bill
        deepLinks.pendingBillID = nil
    }
}
