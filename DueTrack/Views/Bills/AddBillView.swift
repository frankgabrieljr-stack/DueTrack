import SwiftUI

struct AddBillView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var billViewModel: BillViewModel
    
    @State private var name = ""
    @State private var amount = ""
    @State private var startDate = Date()
    @State private var frequency: BillFrequency = .monthly
    @State private var category: BillCategory = .utilities
    @State private var isAutoPay = false
    @State private var notes = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showingSuccess = false
    @State private var customInterval: Int = 1
    @State private var customUnit: CustomRecurrenceUnit = .months
    
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
                                Text(category.displayName)
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
            .navigationTitle("New Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBill()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Bill created successfully!")
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
    
    private var isFormValid: Bool {
        !name.isEmpty && !amount.isEmpty && Double(amount) != nil && Double(amount)! > 0
    }
    
    private func saveBill() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Please enter a valid amount greater than 0"
            showingError = true
            return
        }
        
        isSaving = true
        
        // Extract day of month from selected date for backward compatibility
        let calendar = Calendar.current
        let dueDay = calendar.component(.day, from: startDate)
        
        let success = billViewModel.createBill(
            name: name,
            amount: amountValue,
            startDate: startDate,
            dueDay: dueDay,
            frequency: frequency,
            category: category,
            isAutoPay: isAutoPay,
            notes: notes.isEmpty ? nil : notes,
            customInterval: frequency == .custom ? customInterval : nil,
            customUnit: frequency == .custom ? customUnit : nil
        )
        
        isSaving = false
        
        if success {
            // Add haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            showingSuccess = true
            // Dismiss will be handled by the success alert
        } else {
            errorMessage = billViewModel.errorMessage ?? "Failed to create bill. Please try again."
            showingError = true
        }
    }
}

