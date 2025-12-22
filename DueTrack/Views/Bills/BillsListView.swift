import SwiftUI

struct BillsListView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @State private var searchText = ""
    @State private var filterCategory: BillCategory?
    
    var filteredBills: [Bill] {
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
        NavigationView {
            VStack {
                // Search and Filter
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
                .padding()
                
                // Bills List
                if filteredBills.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("No bills found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredBills, id: \.id) { bill in
                            NavigationLink(destination: BillDetailView(bill: bill)) {
                                BillRowView(bill: bill)
                            }
                        }
                        .onDelete(perform: deleteBills)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Bills")
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
    
    private func deleteBills(at offsets: IndexSet) {
        for index in offsets {
            billViewModel.deleteBill(filteredBills[index])
        }
    }
}

struct BillRowView: View {
    let bill: Bill
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Category Icon
            Image(systemName: BillCategory(rawValue: bill.category)?.icon ?? "ellipsis.circle.fill")
                .foregroundColor(.primaryBlue)
                .font(.title2)
                .frame(width: 40)
            
            // Bill Info
            VStack(alignment: .leading, spacing: 4) {
                Text(bill.name)
                    .font(.headline)
                    .foregroundColor(.adaptiveText)
                
                HStack {
                    Text(bill.amount.currencyString())
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                    
                    Text("•")
                        .foregroundColor(.adaptiveSecondaryText)
                    
                    Text("Due \(DateHelpers.formatDate(bill.nextDueDate))")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
            }
            
            Spacer()
            
            // Status Indicator (uses UI status consistent with detail/dashboard)
            Circle()
                .fill(Color(hex: uiStatus.color))
                .frame(width: 12, height: 12)
        }
        .padding(.vertical, 8)
    }
}

private extension BillRowView {
    var uiStatus: PaymentStatus {
        if paymentViewModel.paymentForCurrentPeriod(for: bill) != nil {
            return .paid
        }
        
        let nextDue = bill.nextDueDate
        let today = Date()
        if nextDue < today {
            return .overdue
        }
        
        let daysUntil = Calendar.current.dateComponents([.day], from: today, to: nextDue).day ?? 0
        if daysUntil <= 7 && daysUntil >= 0 {
            return .upcoming
        }
        return .future
    }
}

