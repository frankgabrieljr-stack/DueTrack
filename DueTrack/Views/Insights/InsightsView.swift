import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Monthly Spending
                    MonthlySpendingCard()
                    
                    // Category Breakdown
                    CategoryBreakdownCard()
                    
                    // Upcoming Bills
                    UpcomingBillsCard()
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
}

struct MonthlySpendingCard: View {
    @EnvironmentObject var billViewModel: BillViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Spending")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)
            
            Text(billViewModel.totalMonthlyOutflow().currencyString())
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primaryBlue)
            
            Text("Total recurring bills per month")
                .font(.subheadline)
                .foregroundColor(.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

struct CategoryBreakdownCard: View {
    @EnvironmentObject var billViewModel: BillViewModel
    
    private var categoryTotals: [(category: BillCategory, total: Double)] {
        let grouped = Dictionary(grouping: billViewModel.bills) { BillCategory(rawValue: $0.category) ?? .other }
        return grouped.map { (category, bills) in
            (category: category, total: bills.reduce(0) { $0 + $1.amount })
        }.sorted { $0.total > $1.total }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)
            
            if categoryTotals.isEmpty {
                Text("No bills yet")
                    .font(.subheadline)
                    .foregroundColor(.adaptiveSecondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(categoryTotals, id: \.category) { item in
                    NavigationLink(destination: CategoryBillsDetailView(category: item.category)) {
                        HStack(spacing: 12) {
                            Image(systemName: item.category.icon)
                                .foregroundColor(.primaryBlue)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                                .background(Color.primaryBlue.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(item.category.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveText)
                            
                            Spacer()
                            
                            Text(item.total.currencyString())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveText)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

struct CategoryBillsDetailView: View {
    let category: BillCategory
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    private var billsInCategory: [Bill] {
        billViewModel.bills
            .filter { $0.category == category.rawValue }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }
    
    var body: some View {
        List {
            if billsInCategory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.adaptiveSecondaryText.opacity(0.6))
                    Text("No bills in this category")
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                ForEach(billsInCategory, id: \.id) { bill in
                    NavigationLink(destination: BillDetailView(bill: bill)) {
                        BillRowView(bill: bill)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle(category.displayName)
    }
}

struct UpcomingBillsCard: View {
    @EnvironmentObject var billViewModel: BillViewModel
    
    private var upcomingBills: [Bill] {
        billViewModel.upcomingBills().prefix(5).map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Bills")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)
            
            if upcomingBills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentGreen.opacity(0.5))
                    Text("All caught up!")
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                    Text("No upcoming bills")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(upcomingBills, id: \.id) { bill in
                    HStack(spacing: 12) {
                        // Status indicator
                        Circle()
                            .fill(Color(hex: bill.paymentStatus.color))
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bill.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.adaptiveText)
                            Text(DateHelpers.formatDate(bill.nextDueDate))
                                .font(.caption)
                                .foregroundColor(.adaptiveSecondaryText)
                        }
                        
                        Spacer()
                        
                        Text(bill.amount.currencyString())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveText)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

