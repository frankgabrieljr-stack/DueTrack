import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var selectedView: DashboardViewType = .calendar
    @State private var selectedMonth = Date() // Track the selected month from calendar
    
    enum DashboardViewType {
        case calendar, list
    }
    
    var body: some View {
        NavigationView {
            Group {
                if selectedView == .calendar {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Quick Stats - pass the selected month
                            QuickStatsView(selectedMonth: selectedMonth)
                                .padding()
                                .background(Color.adaptiveBackground)
                                .onAppear {
                                    // Fetch all payments when dashboard appears
                                    paymentViewModel.fetchAllPayments()
                                }
                                .onChange(of: paymentViewModel.payments.count) { _ in
                                    // Refresh when payments change
                                    paymentViewModel.fetchAllPayments()
                                }
                            
                            // View Toggle
                            Picker("View", selection: $selectedView) {
                                Text("Calendar").tag(DashboardViewType.calendar)
                                Text("List").tag(DashboardViewType.list)
                            }
                            .pickerStyle(.segmented)
                            .padding()
                            
                            // Calendar content
                            CalendarView(selectedMonth: $selectedMonth)
                                .padding(.horizontal)
                                .padding(.bottom)
                        }
                    }
                } else {
                    // List view: show stats + searchable bill list
                    DashboardBillsListView(selectedView: $selectedView)
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: AddBillView()) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.primaryBlue)
                    }
                }
            }
        }
    }
}

struct QuickStatsView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    let selectedMonth: Date
    
    private var monthlyTotal: Double {
        billViewModel.totalMonthlyOutflow(for: selectedMonth)
    }
    
    private var totalPaid: Double {
        paymentViewModel.totalPaidForMonth(for: selectedMonth)
    }
    
    private var remainingToPay: Double {
        // Remaining = sum of all unpaid occurrences in the selected month.
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        var remaining: Double = 0
        
        for bill in billViewModel.bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            
            let customInterval = (frequency == .custom && bill.customInterval > 0)
                ? Int(bill.customInterval)
                : nil
            let customUnit = (frequency == .custom)
                ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "")
                : nil
            
            // All scheduled occurrences of this bill in the selected month
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: customInterval,
                customUnit: customUnit,
                for: selectedMonth
            )
            
            // Payments for this bill
            let payments = paymentViewModel.paymentHistory(for: bill)
            
            for occurrence in occurrences {
                // Extra safety, though occurrencesForMonth should already clamp to the month
                guard occurrence >= startOfMonth && occurrence <= endOfMonth else { continue }
                
                let isPaid = DateHelpers.isOccurrencePaid(
                    occurrenceDate: occurrence,
                    frequency: frequency,
                    payments: payments,
                    customInterval: customInterval,
                    customUnit: customUnit
                )
                
                if !isPaid {
                    remaining += bill.amount
                }
            }
        }
        
        return remaining
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // First row: Monthly and Remaining cards
            HStack(spacing: 20) {
                StatCard(
                    title: "Monthly",
                    value: monthlyTotal.currencyString(),
                    color: .primaryBlue,
                    destination: AnyView(MonthlyBillsDetailView()),
                    isLarge: false
                )
                .accessibilityLabel("Open Monthly details")
                .accessibilityHint("Shows all bills contributing to monthly total")
                
                StatCard(
                    title: "Remaining",
                    value: remainingToPay.currencyString(),
                    color: remainingToPay > 0 ? .upcomingYellow : .accentGreen,
                    destination: nil,
                    isLarge: false
                )
                .accessibilityLabel("Remaining to pay this month")
                .accessibilityHint("Shows how much is left to pay after payments made")
            }
            
            // Second row: Upcoming and Overdue cards
            HStack(spacing: 20) {
                StatCard(
                    title: "Upcoming",
                    value: "\(billViewModel.upcomingBills().count)",
                    color: .upcomingYellow,
                    destination: AnyView(UpcomingBillsDetailView())
                )
                .accessibilityLabel("Open Upcoming bills")
                .accessibilityHint("Shows bills due in the next 30 days")
                
                StatCard(
                    title: "Overdue",
                    value: billViewModel.overdueAmount().currencyString(),
                    color: .overdueRed,
                    destination: AnyView(OverdueBillsDetailView())
                )
                .accessibilityLabel("Open Overdue bills")
                .accessibilityHint("Shows bills that are past due")
            }
            
            // Third row: Paid this month
            HStack(spacing: 20) {
                StatCard(
                    title: "Paid This Month",
                    value: paymentViewModel.totalPaidForMonth(for: selectedMonth).currencyString(),
                    color: .accentGreen,
                    destination: AnyView(PaidBillsDetailView(selectedMonth: selectedMonth)),
                    isLarge: false
                )
                .accessibilityLabel("Open Paid bills for this month")
                .accessibilityHint("Shows all payments recorded in the selected month")
            }
            
            // Upcoming Bills in Next Week Section
            UpcomingWeekBillsView()
        }
    }
}

struct UpcomingWeekBillsView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    private var upcomingBills: [(bill: Bill, nextDueDate: Date)] {
        billViewModel.billsDueInNextWeek()
    }
    
    private func isBillPaidForDate(_ bill: Bill, dueDate: Date) -> Bool {
        let calendar = Calendar.current
        return paymentViewModel.paymentHistory(for: bill).contains { payment in
            // Check if payment is for this specific occurrence
            calendar.isDate(payment.datePaid, inSameDayAs: dueDate) ||
            (payment.datePaid <= dueDate && payment.datePaid > calendar.date(byAdding: .month, value: -1, to: dueDate)!)
        }
    }
    
    var body: some View {
        if !upcomingBills.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Due This Week")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.adaptiveText)
                    
                    Spacer()
                    
                    Text("\(upcomingBills.count) bill\(upcomingBills.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                
                ForEach(Array(upcomingBills.prefix(5)), id: \.bill.id) { item in
                    let isPaid = isBillPaidForDate(item.bill, dueDate: item.nextDueDate)
                    
                    NavigationLink(destination: BillDetailView(bill: item.bill)) {
                        HStack(spacing: 12) {
                            // Bill icon with checkmark overlay if paid
                            ZStack {
                                Image(systemName: BillCategory(rawValue: item.bill.category)?.icon ?? "ellipsis.circle.fill")
                                    .foregroundColor(isPaid ? .accentGreen : .primaryBlue)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background((isPaid ? Color.accentGreen : Color.primaryBlue).opacity(0.1))
                                    .clipShape(Circle())
                                
                                // Checkmark overlay
                                if isPaid {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.accentGreen)
                                        .font(.caption)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                        .offset(x: 12, y: -12)
                                }
                            }
                            
                            // Bill info
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(item.bill.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(isPaid ? .adaptiveSecondaryText : .adaptiveText)
                                        .strikethrough(isPaid)
                                    
                                    if isPaid {
                                        Text("Paid")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentGreen)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                HStack(spacing: 4) {
                                    Text(DateHelpers.formatDate(item.nextDueDate))
                                        .font(.caption)
                                        .foregroundColor(isPaid ? .adaptiveSecondaryText : .adaptiveSecondaryText)
                                    
                                    // Days until indicator
                                    let daysUntil = DateHelpers.daysUntil(item.nextDueDate)
                                    if daysUntil == 0 {
                                        Text("• Today")
                                            .font(.caption)
                                            .foregroundColor(isPaid ? .accentGreen : .upcomingYellow)
                                    } else if daysUntil == 1 {
                                        Text("• Tomorrow")
                                            .font(.caption)
                                            .foregroundColor(isPaid ? .accentGreen : .upcomingYellow)
                                    } else {
                                        Text("• In \(daysUntil) days")
                                            .font(.caption)
                                            .foregroundColor(isPaid ? .accentGreen : .adaptiveSecondaryText)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Amount
                            Text(item.bill.amount.currencyString())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(isPaid ? .accentGreen : .adaptiveText)
                                .monospacedDigit()
                                .strikethrough(isPaid)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .opacity(isPaid ? 0.7 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
            .cardStyle()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    let destination: AnyView?
    let isLarge: Bool
    
    init(title: String, value: String, color: Color, destination: AnyView? = nil, isLarge: Bool = false) {
        self.title = title
        self.value = value
        self.color = color
        self.destination = destination
        self.isLarge = isLarge
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isLarge ? 8 : 6) {
            Text(title)
                .font(isLarge ? .subheadline : .caption)
                .fontWeight(.medium)
                .foregroundColor(.adaptiveSecondaryText)
            Text(value)
                .font(.system(size: isLarge ? 28 : 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(isLarge ? 0.7 : 0.8)
                .allowsTightening(true)
                .truncationMode(.tail)
                .monospacedDigit()
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isLarge ? 20 : 16)
        .cardStyle()
        .contentShape(Rectangle())
        .if(destination != nil) { view in
            NavigationLink(destination: destination!) {
                view
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Dashboard List View (for "List" toggle)

struct DashboardBillsListView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @Binding var selectedView: DashboardView.DashboardViewType
    
    @State private var searchText = ""
    @State private var filterCategory: BillCategory?
    
    private var filteredBills: [Bill] {
        var bills = billViewModel.bills
        
        if !searchText.isEmpty {
            bills = bills.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let category = filterCategory {
            bills = bills.filter { $0.category == category.rawValue }
        }
        
        return bills.sorted { $0.nextDueDate < $1.nextDueDate }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Quick Stats - use current month in list mode
                QuickStatsView(selectedMonth: Date())
                    .padding()
                    .background(Color.adaptiveBackground)
                
                // View Toggle
                Picker("View", selection: $selectedView) {
                    Text("Calendar").tag(DashboardView.DashboardViewType.calendar)
                    Text("List").tag(DashboardView.DashboardViewType.list)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Search / filter
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Search bills...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Menu {
                            Button("All Categories") {
                                filterCategory = nil
                            }
                            ForEach(BillCategory.allCases, id: \.self) { category in
                                Button(category.displayName) {
                                    filterCategory = category
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    
                    if filteredBills.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("No bills found")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(filteredBills, id: \.id) { bill in
                                NavigationLink(destination: BillDetailView(bill: bill)) {
                                    BillRowView(bill: bill)
                                        .padding(.vertical, 4)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                            }
                        }
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .onAppear {
            // Ensure data is fresh when switching to list mode
            billViewModel.fetchBills()
            paymentViewModel.fetchAllPayments()
        }
    }
}


