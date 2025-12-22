import SwiftUI

struct MonthlyBillsDetailView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var selectedBill: Bill?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Monthly")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                    Text(billViewModel.totalMonthlyOutflow().currencyString())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primaryBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cardStyle()
                
                // Bills List
                let monthlyBills = billViewModel.monthlyBills()
                
                if monthlyBills.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.adaptiveSecondaryText.opacity(0.5))
                        Text("No monthly bills")
                            .font(.headline)
                            .foregroundColor(.adaptiveSecondaryText)
                        Text("Add bills to see them here")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(monthlyBills, id: \.id) { bill in
                        Button(action: { selectedBill = bill }) {
                            BillRowView(bill: bill)
                                .padding()
                                .cardStyle()
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Monthly Bills")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: Binding(get: { selectedBill != nil }, set: { if !$0 { selectedBill = nil } })) {
            if let bill = selectedBill {
                BillDetailView(bill: bill)
                    .environmentObject(billViewModel)
                    .environmentObject(paymentViewModel)
            }
        }
    }
}

