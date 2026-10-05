import SwiftUI

struct OverdueBillsDetailView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var selectedBill: Bill?
    
    private var overdueItems: [(bill: Bill, overdueSince: Date, overdueCount: Int)] {
        _ = paymentViewModel.payments
        return billViewModel.overdueBillItems()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Overdue Amount")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                    Text(billViewModel.overdueAmount().currencyString())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.overdueRed)
                    Text("\(billViewModel.overdueOccurrenceCount()) overdue occurrence\(billViewModel.overdueOccurrenceCount() == 1 ? "" : "s") across \(overdueItems.count) bill\(overdueItems.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cardStyle()
                
                if overdueItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.accentGreen.opacity(0.5))
                        Text("No overdue bills 🎉")
                            .font(.headline)
                            .foregroundColor(.adaptiveSecondaryText)
                        Text("All bills are paid on time!")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(overdueItems, id: \.bill.objectID) { item in
                        Button(action: { selectedBill = item.bill }) {
                            HStack(spacing: 12) {
                                Image(systemName: BillCategory(rawValue: item.bill.category)?.icon ?? "ellipsis.circle.fill")
                                    .foregroundColor(.overdueRed)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                    .background(Color.overdueRed.opacity(0.12))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.bill.name)
                                        .font(.headline)
                                        .foregroundColor(.adaptiveText)
                                    
                                    Text("Overdue since \(DateHelpers.formatDate(item.overdueSince))")
                                        .font(.caption)
                                        .foregroundColor(.overdueRed)
                                    
                                    if item.overdueCount > 1 {
                                        Text("\(item.overdueCount) unpaid occurrences")
                                            .font(.caption2)
                                            .foregroundColor(.adaptiveSecondaryText)
                                    }
                                }
                                
                                Spacer()
                                
                                Text((item.bill.amount * Double(item.overdueCount)).currencyString())
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.overdueRed)
                                    .monospacedDigit()
                            }
                            .padding()
                            .cardStyle()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Overdue Bills")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            paymentViewModel.fetchAllPayments()
            billViewModel.fetchBills()
        }
        .sheet(isPresented: Binding(get: { selectedBill != nil }, set: { if !$0 { selectedBill = nil } }), onDismiss: {
            paymentViewModel.fetchAllPayments()
            billViewModel.fetchBills()
        }) {
            if let bill = selectedBill {
                BillDetailView(bill: bill)
                    .environmentObject(billViewModel)
                    .environmentObject(paymentViewModel)
            }
        }
    }
}
