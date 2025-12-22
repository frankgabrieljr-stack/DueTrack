import SwiftUI

struct UpcomingBillsDetailView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var selectedBill: Bill?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming Bills")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                    Text("\(billViewModel.upcomingBillsWithinDays().count) bills")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.upcomingYellow)
                    Text("Due within the next 30 days")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cardStyle()
                
                // Bills List
                let upcomingBills = billViewModel.upcomingBillsWithinDays()
                
                if upcomingBills.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.accentGreen.opacity(0.5))
                        Text("No upcoming bills 🎉")
                            .font(.headline)
                            .foregroundColor(.adaptiveSecondaryText)
                        Text("All caught up!")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(upcomingBills, id: \.id) { bill in
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
        .navigationTitle("Upcoming Bills")
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

