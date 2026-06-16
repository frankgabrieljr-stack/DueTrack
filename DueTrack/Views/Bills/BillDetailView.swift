import SwiftUI

struct BillDetailView: View {
    let bill: Bill
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var showingPaymentSheet = false
    @State private var showingEditSheet = false
    @State private var showingAlreadyPaidToast = false
    @State private var paymentDueDateForSheet = Date()
    @State private var paymentPaidDateForSheet = Date()
    @State private var overdueCountForSheet = 0
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Bill Header
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: BillCategory(rawValue: bill.category)?.icon ?? "ellipsis.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.primaryBlue)
                        
                        VStack(alignment: .leading) {
                            Text(bill.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveText)
                            
                            Text(BillCategory(rawValue: bill.category)?.displayName ?? bill.category)
                                .font(.subheadline)
                                .foregroundColor(.adaptiveSecondaryText)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Amount")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveSecondaryText)
                            Text(bill.amount.currencyString())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(headerDueLabel)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveSecondaryText)
                            Text(DateHelpers.formatDate(bill.nextDueDate))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveText)
                        }
                    }
                    
                    // Status Badge
                    HStack {
                        Circle()
                            .fill(Color(hex: currentStatus.color))
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.subheadline)
                            .foregroundColor(Color(hex: currentStatus.color))
                    }

                    if currentStatus == .overdue, let overdueSince = oldestUnpaidOverdueDate {
                        Text("Unpaid since \(DateHelpers.formatDate(overdueSince))")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }

                    if let lastPaidDate = lastPaymentDate {
                        Text("Last paid \(DateHelpers.formatDate(lastPaidDate))")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }

                    if let paidThroughDate = paidThroughDate, currentStatus != .paid {
                        Text("Paid through \(DateHelpers.formatDate(paidThroughDate)); next unpaid bill is due \(DateHelpers.formatDate(bill.nextDueDate)).")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }

                    if currentStatus == .overdue, paymentViewModel.paymentForCurrentPeriod(for: bill) != nil {
                        Text("A recent payment was recorded, but an older bill is still unpaid.")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                }
                .padding()
                .cardStyle()
                
                // Quick Actions
                VStack(spacing: 12) {
                    let overdueOccurrences = paymentViewModel.unpaidOverdueOccurrences(for: bill)
                    if !overdueOccurrences.isEmpty {
                        Button(action: {
                            if let oldestOverdueDate = overdueOccurrences.first {
                                paymentDueDateForSheet = oldestOverdueDate
                                paymentPaidDateForSheet = Date()
                                overdueCountForSheet = overdueOccurrences.count
                                showingPaymentSheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(overdueOccurrences.count == 1 ? "Mark Overdue Paid" : "Mark All Overdue Paid")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    } else if paymentViewModel.isBillPaid(bill) {
                        // Bill is paid - show "Mark Unpaid" button
                        Button(action: {
                            paymentViewModel.unmarkBillAsPaid(bill)
                            // Refresh all payments for dashboard
                            paymentViewModel.fetchAllPayments()
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Mark Unpaid")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.overdueRed)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    } else {
                        // Bill is not paid - show "Mark Paid" button
                        Button(action: {
                            if paymentViewModel.paymentForCurrentPeriod(for: bill) != nil && bill.paymentStatus != .overdue {
                                showAlreadyPaidToast()
                            } else {
                                paymentDueDateForSheet = bill.nextDueDate
                                paymentPaidDateForSheet = Date()
                                overdueCountForSheet = 0
                                showingPaymentSheet = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text(lastPaymentDate == nil ? "Mark Paid" : "Pay Next Due")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentGreen)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: { showingEditSheet = true }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primaryBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                // Payment History
                PaymentHistoryView(bill: bill)
                    .onAppear {
                        paymentViewModel.fetchPayments(for: bill.id)
                    }
                
                // Notes
                if let notes = bill.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.adaptiveText)
                        Text(notes)
                            .font(.body)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                    .padding()
                    .cardStyle()
                }
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            if showingAlreadyPaidToast {
                Text("Already paid for this period")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(10)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(bill.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPaymentSheet) {
            PaymentSheet(
                bill: bill,
                dueDate: paymentDueDateForSheet,
                initialPaymentDate: paymentPaidDateForSheet,
                isOverdue: overdueCountForSheet > 0,
                overdueCount: overdueCountForSheet
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            EditBillView(bill: bill)
        }
    }
}

private extension BillDetailView {
    func showAlreadyPaidToast() {
        withAnimation {
            showingAlreadyPaidToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showingAlreadyPaidToast = false
            }
        }
    }

    /// UI-facing status that prioritizes "Paid" when there's a current-period payment.
    var currentStatus: PaymentStatus {
        if bill.paymentStatus == .overdue {
            return .overdue
        }

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
    
    var statusText: String {
        switch currentStatus {
        case .paid: return "Paid"
        case .overdue: return "Overdue"
        case .upcoming: return "Upcoming"
        case .future: return "Future"
        }
    }

    var headerDueLabel: String {
        currentStatus == .overdue ? "Overdue Since" : "Next Due"
    }

    var lastPaymentDate: Date? {
        paymentViewModel.paymentHistory(for: bill)
            .map { $0.datePaid }
            .sorted(by: >)
            .first
    }

    var paidThroughDate: Date? {
        paymentViewModel.paymentHistory(for: bill)
            .map { $0.effectiveDueDate }
            .sorted(by: >)
            .first
    }

    var oldestUnpaidOverdueDate: Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let freq = BillFrequency(rawValue: bill.frequency) ?? .monthly
        let startDate = bill.createdDate ?? today
        let customIntervalValue = freq == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil
        let customUnitValue = freq == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        let payments = paymentViewModel.paymentHistory(for: bill)

        var occurrence = startDate
        var safetyCounter = 0
        while occurrence < today && safetyCounter < 1000 {
            let isPaid = DateHelpers.isOccurrencePaid(
                occurrenceDate: occurrence,
                frequency: freq,
                payments: payments,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )

            if !isPaid {
                return occurrence
            }

            let next = DateHelpers.nextOccurrence(
                from: occurrence,
                frequency: freq,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            if next <= occurrence {
                break
            }
            occurrence = next
            safetyCounter += 1
        }

        return nil
    }
}

struct PaymentHistoryView: View {
    let bill: Bill
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var showingDeleteConfirmation = false
    @State private var paymentToDelete: Payment?
    @State private var paymentToEdit: Payment?
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment History")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)
            
            let history = paymentViewModel.paymentHistory(for: bill)
            let currentPeriodPayment = paymentViewModel.paymentForCurrentPeriod(for: bill)
            
            if history.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30))
                        .foregroundColor(.adaptiveSecondaryText.opacity(0.5))
                    Text("No payment history")
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(history, id: \.id) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(payment.amount.currencyString())
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.adaptiveText)
                                
                                if payment.id == currentPeriodPayment?.id {
                                    Text("Current period")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.accentGreen)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentGreen.opacity(0.15))
                                        .cornerRadius(4)
                                }

                                if payment.wasPaidLate {
                                    Text("Late")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.overdueRed)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.overdueRed.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                            
                            if payment.dueDate != nil {
                                Text("Due \(DateHelpers.formatDate(payment.effectiveDueDate)) • Paid \(DateHelpers.formatDate(payment.datePaid))")
                                    .font(.caption)
                                    .foregroundColor(.adaptiveSecondaryText)
                            } else {
                                Text("Paid \(DateHelpers.formatDate(payment.datePaid))")
                                    .font(.caption)
                                    .foregroundColor(.adaptiveSecondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        if let notes = payment.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(.adaptiveSecondaryText)
                        }

                        Button(action: {
                            paymentToEdit = payment
                            showingEditSheet = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.primaryBlue)
                                .padding(8)
                        }

                        Button(action: {
                            paymentToDelete = payment
                            showingDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.overdueRed)
                                .padding(8)
                        }
                    }
                    .padding()
                    .cardStyle()
                }
            }
        }
        .alert("Remove Payment?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if let payment = paymentToDelete {
                    paymentViewModel.deletePayment(payment)
                    // Refresh all payments for dashboard
                    paymentViewModel.fetchAllPayments()
                }
            }
        } message: {
            Text("This will remove the payment from history and adjust totals.")
        }
        .sheet(isPresented: $showingEditSheet) {
            if let payment = paymentToEdit {
                PaymentEditSheet(payment: payment)
                    .environmentObject(paymentViewModel)
            }
        }
    }
}

struct PaymentSheet: View {
    let bill: Bill
    let dueDate: Date
    let initialPaymentDate: Date
    let isOverdue: Bool
    let overdueCount: Int
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    @State private var amount = ""
    @State private var notes = ""
    @State private var selectedDueDate: Date
    @State private var datePaid: Date
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingAlreadyPaidToast = false
    @State private var toastMessage = "Already paid for this period"

    init(
        bill: Bill,
        dueDate: Date = Date(),
        initialPaymentDate: Date = Date(),
        isOverdue: Bool = false,
        overdueCount: Int = 0
    ) {
        self.bill = bill
        self.dueDate = dueDate
        self.initialPaymentDate = initialPaymentDate
        self.isOverdue = isOverdue
        self.overdueCount = overdueCount
        _selectedDueDate = State(initialValue: dueDate)
        _datePaid = State(initialValue: initialPaymentDate)
    }
    
    var body: some View {
        NavigationView {
            Form {
                if isOverdue {
                    Section {
                        let countText = overdueCount == 1 ? "1 overdue bill" : "\(overdueCount) overdue bills"
                        Text("This will mark \(countText) as paid.")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                        Text("Oldest due date: \(DateHelpers.formatDate(dueDate))")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                }
                Section(header: Text("Payment Amount")) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField(bill.amount.currencyString(), text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if !isOverdue {
                    Section(header: Text("Bill Due Date")) {
                        DatePicker(
                            "Apply To",
                            selection: $selectedDueDate,
                            displayedComponents: .date
                        )

                        Text("Use this to pay an upcoming bill early.")
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }

                Section(header: Text("Payment Date")) {
                    DatePicker(
                        "Paid On",
                        selection: $datePaid,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("Mark as Paid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePayment()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
            .overlay(alignment: .bottom) {
                if showingAlreadyPaidToast {
                    Text(toastMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private func savePayment() {
        if isOverdue {
            if overdueCount == 0 {
                toastMessage = "No overdue bills to mark"
                showToast()
                return
            }
        } else if paymentViewModel.paymentExists(for: bill, on: selectedDueDate) != nil {
            toastMessage = "Already paid for this period"
            showToast()
            return
        }

        let paymentAmount: Double
        if amount.isEmpty {
            paymentAmount = bill.amount
        } else if let amountValue = Double(amount), amountValue > 0 {
            paymentAmount = amountValue
        } else {
            errorMessage = "Please enter a valid amount greater than 0"
            showingError = true
            return
        }
        
        isSaving = true
        let success: Bool
        if isOverdue {
            success = paymentViewModel.markAllOverdueAsPaid(
                bill,
                paidOn: datePaid,
                amount: paymentAmount,
                notes: notes.isEmpty ? nil : notes
            )
        } else {
            success = paymentViewModel.markBillAsPaid(
                bill,
                on: selectedDueDate,
                paidOn: datePaid,
                amount: paymentAmount,
                notes: notes.isEmpty ? nil : notes
            )
        }
        
        // Small delay to ensure save completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSaving = false
            if success {
                // Add haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Refresh payments after saving (both for this bill and all payments for dashboard)
                paymentViewModel.fetchPayments(for: bill.id)
                paymentViewModel.fetchAllPayments()
                dismiss()
            } else {
                errorMessage = "Failed to save payment. Please try again."
                showingError = true
            }
        }
    }

    private func showToast() {
        withAnimation {
            showingAlreadyPaidToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                showingAlreadyPaidToast = false
            }
        }
    }
}

struct PaymentEditSheet: View {
    let payment: Payment
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentViewModel: PaymentViewModel

    @State private var amount: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var datePaid: Date
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init(payment: Payment) {
        self.payment = payment
        _amount = State(initialValue: String(format: "%.2f", payment.amount))
        _notes = State(initialValue: payment.notes ?? "")
        _dueDate = State(initialValue: payment.effectiveDueDate)
        _datePaid = State(initialValue: payment.datePaid)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Payment Amount")) {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section(header: Text("Bill Due Date")) {
                    DatePicker(
                        "Due On",
                        selection: $dueDate,
                        displayedComponents: .date
                    )
                }

                Section(header: Text("Payment Date")) {
                    DatePicker(
                        "Date Paid",
                        selection: $datePaid,
                        displayedComponents: .date
                    )
                }

                Section(header: Text("Notes (Optional)")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Edit Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePayment()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
    }

    private func savePayment() {
        let paymentAmount: Double
        if amount.isEmpty {
            paymentAmount = payment.amount
        } else if let amountValue = Double(amount), amountValue > 0 {
            paymentAmount = amountValue
        } else {
            errorMessage = "Please enter a valid amount greater than 0"
            showingError = true
            return
        }

        isSaving = true
        let success = paymentViewModel.updatePayment(
            payment,
            amount: paymentAmount,
            datePaid: datePaid,
            dueDate: dueDate,
            notes: notes.isEmpty ? nil : notes
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isSaving = false
            if success {
                dismiss()
            } else {
                errorMessage = "Failed to update payment. Please try again."
                showingError = true
            }
        }
    }
}

struct EditBillView: View {
    let bill: Bill
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var billViewModel: BillViewModel
    
    @State private var name: String
    @State private var amount: String
    @State private var startDate: Date
    @State private var frequency: BillFrequency
    @State private var category: BillCategory
    @State private var isAutoPay: Bool
    @State private var notes: String
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var customInterval: Int
    @State private var customUnit: CustomRecurrenceUnit
    
    init(bill: Bill) {
        self.bill = bill
        _name = State(initialValue: bill.name)
        _amount = State(initialValue: String(format: "%.2f", bill.amount))
        _startDate = State(initialValue: bill.createdDate ?? Date())
        _frequency = State(initialValue: BillFrequency(rawValue: bill.frequency) ?? .monthly)
        _category = State(initialValue: BillCategory(rawValue: bill.category) ?? .utilities)
        _isAutoPay = State(initialValue: bill.isAutoPay)
        _notes = State(initialValue: bill.notes ?? "")
        _customInterval = State(initialValue: bill.customInterval > 0 ? Int(bill.customInterval) : 1)
        _customUnit = State(initialValue: CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") ?? .months)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Bill Information")) {
                    TextField("Bill Name", text: $name)
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(BillCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }
                
                Section(header: Text("Payment Schedule")) {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(BillFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    
                    Toggle("AutoPay", isOn: $isAutoPay)
                    
                    if frequency == .custom {
                        HStack {
                            Picker("Every", selection: $customInterval) {
                                ForEach(1...6, id: \.self) { value in
                                    Text("\(value)").tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Picker("", selection: $customUnit) {
                                Text("day(s)").tag(CustomRecurrenceUnit.days)
                                Text("week(s)").tag(CustomRecurrenceUnit.weeks)
                                Text("month(s)").tag(CustomRecurrenceUnit.months)
                                Text("year(s)").tag(CustomRecurrenceUnit.years)
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount greater than 0"
            showingError = true
            return
        }
        
        isSaving = true
        
        let calendar = Calendar.current
        let dueDay = calendar.component(.day, from: startDate)
        
        bill.name = name
        bill.amount = amountValue
        bill.dueDay = Int32(dueDay)
        bill.frequency = frequency.rawValue
        bill.category = category.rawValue
        bill.isAutoPay = isAutoPay
        bill.notes = notes.isEmpty ? nil : notes
        // Update createdDate to reflect new start date
        bill.createdDate = startDate
        if frequency == .custom {
            bill.customInterval = Int32(customInterval)
            bill.customUnit = customUnit.rawValue
        } else {
            bill.customInterval = 0
            bill.customUnit = nil
        }
        
        let success = billViewModel.updateBill(bill)
        isSaving = false
        
        if success {
            // Add haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
        } else {
            errorMessage = billViewModel.errorMessage ?? "Failed to update bill. Please try again."
            showingError = true
        }
    }
}

