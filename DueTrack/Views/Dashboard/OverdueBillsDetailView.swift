import SwiftUI

struct OverdueBillsDetailView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var selectedBill: Bill?
    
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
                    Text("\(billViewModel.overdueBills().count) bills")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cardStyle()
                
                // Bills List
                let overdueBills = billViewModel.overdueBills()
                
                if overdueBills.isEmpty {
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
                    ForEach(overdueBills, id: \.id) { bill in
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
        .navigationTitle("Overdue Bills")
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

