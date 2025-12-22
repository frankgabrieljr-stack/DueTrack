import SwiftUI

struct PaidBillsDetailView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    let selectedMonth: Date
    
    private var paymentsThisMonth: [Payment] {
        paymentViewModel.paymentsForMonth(selectedMonth)
    }
    
    private var totalPaidThisMonth: Double {
        paymentViewModel.totalPaidForMonth(for: selectedMonth)
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Summary Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paid in \(monthTitle)")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                    Text(totalPaidThisMonth.currencyString())
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.accentGreen)
                    Text("\(paymentsThisMonth.count) payment\(paymentsThisMonth.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .cardStyle()
                
                // Payments List
                if paymentsThisMonth.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.adaptiveSecondaryText.opacity(0.5))
                        Text("No payments recorded this month")
                            .font(.headline)
                            .foregroundColor(.adaptiveSecondaryText)
                        Text("Mark bills as paid from the dashboard or bill details to see them here.")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(paymentsThisMonth, id: \.id) { payment in
                        PaidBillRow(payment: payment)
                            .padding()
                            .cardStyle()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Paid Bills")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            // Ensure payments are up to date
            paymentViewModel.fetchAllPayments()
        }
    }
}

struct PaidBillRow: View {
    let payment: Payment
    @EnvironmentObject var billViewModel: BillViewModel
    
    private var bill: Bill? {
        billViewModel.bills.first { $0.id == payment.billId }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Category icon (if bill is still present)
            if let bill = bill,
               let category = BillCategory(rawValue: bill.category) {
                Image(systemName: category.icon)
                    .foregroundColor(.primaryBlue)
                    .font(.title2)
                    .frame(width: 40)
            } else {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.adaptiveSecondaryText)
                    .font(.title2)
                    .frame(width: 40)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(bill?.name ?? "Bill")
                    .font(.headline)
                    .foregroundColor(.adaptiveText)
                
                HStack(spacing: 4) {
                    Text(payment.amount.currencyString())
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                    
                    Text("•")
                        .foregroundColor(.adaptiveSecondaryText)
                    
                    Text(DateHelpers.formatDate(payment.datePaid))
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                
                if let notes = payment.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}


