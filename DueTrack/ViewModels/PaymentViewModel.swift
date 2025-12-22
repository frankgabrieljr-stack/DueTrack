import Foundation
import CoreData
import Combine

class PaymentViewModel: ObservableObject {
    @Published var payments: [Payment] = []
    @Published var isLoading = false
    
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    // MARK: - Fetch Payments
    func fetchPayments(for billId: UUID? = nil) {
        let request: NSFetchRequest<Payment> = Payment.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Payment.datePaid, ascending: false)]
        
        if let billId = billId {
            request.predicate = NSPredicate(format: "billId == %@", billId as CVarArg)
        }
        
        do {
            payments = try coreDataManager.viewContext.fetch(request)
        } catch {
            print("Error fetching payments: \(error)")
        }
    }
    
    // MARK: - Fetch All Payments
    func fetchAllPayments() {
        fetchPayments(for: nil)
    }
    
    // MARK: - Create Payment
    func createPayment(
        for bill: Bill,
        amount: Double,
        datePaid: Date = Date(),
        notes: String? = nil
    ) -> Bool {
        let context = coreDataManager.viewContext
        let payment = Payment(context: context)
        
        payment.id = UUID()
        payment.billId = bill.id
        payment.amount = amount
        payment.datePaid = datePaid
        payment.isPaid = true
        payment.notes = notes
        payment.bill = bill
        
        let saved = coreDataManager.save()
        if saved {
            fetchPayments(for: bill.id)
            fetchAllPayments() // Refresh all payments for dashboard
            
            // Cancel old notifications and schedule new ones for next occurrence
            NotificationManager.shared.cancelNotifications(for: bill.id)
            Task {
                // Ensure authorization is granted
                let authorized = await NotificationManager.shared.requestAuthorization()
                if authorized {
                    NotificationManager.shared.scheduleBillReminder(for: bill, daysBefore: [1, 3, 7])
                    NotificationManager.shared.scheduleOverdueAlert(for: bill)
                }
            }
        } else {
            context.delete(payment)
            print("Failed to save payment")
        }
        return saved
    }
    
    // MARK: - Mark Bill as Paid
    func markBillAsPaid(_ bill: Bill, amount: Double? = nil, notes: String? = nil) -> Bool {
        let paymentAmount = amount ?? bill.amount
        return createPayment(for: bill, amount: paymentAmount, notes: notes)
    }
    
    /// Mark a specific bill occurrence (for a given due date) as paid.
    /// This is useful when marking a past calendar date as paid.
    func markBillAsPaid(
        _ bill: Bill,
        on occurrenceDate: Date,
        amount: Double? = nil,
        notes: String? = nil
    ) -> Bool {
        let paymentAmount = amount ?? bill.amount
        return createPayment(for: bill, amount: paymentAmount, datePaid: occurrenceDate, notes: notes)
    }
    
    // MARK: - Get Payment History for Bill
    func paymentHistory(for bill: Bill) -> [Payment] {
        return payments.compactMap { payment in
            guard let id = payment.billId else { return nil }
            return id == bill.id ? payment : nil
        }
    }
    
    // MARK: - Total Paid for Bill
    func totalPaid(for bill: Bill) -> Double {
        return paymentHistory(for: bill).reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Is Bill Paid
    func isBillPaid(_ bill: Bill) -> Bool {
        let nextDueDate = bill.nextDueDate
        let calendar = Calendar.current
        
        return paymentHistory(for: bill).contains { payment in
            calendar.isDate(payment.datePaid, inSameDayAs: nextDueDate) ||
            (payment.datePaid <= nextDueDate && payment.datePaid > calendar.date(byAdding: .month, value: -1, to: nextDueDate)!)
        }
    }
    
    // MARK: - Get Payment for Current Period
    func paymentForCurrentPeriod(for bill: Bill) -> Payment? {
        let nextDueDate = bill.nextDueDate
        let calendar = Calendar.current
        
        return paymentHistory(for: bill).first { payment in
            calendar.isDate(payment.datePaid, inSameDayAs: nextDueDate) ||
            (payment.datePaid <= nextDueDate && payment.datePaid > calendar.date(byAdding: .month, value: -1, to: nextDueDate)!)
        }
    }
    
    // MARK: - Delete Payment (Unmark as Paid)
    func deletePayment(_ payment: Payment) {
        // CRITICAL: Save ALL references BEFORE deleting the payment object
        // Access properties while the object is still valid and not deleted
        guard !payment.isDeleted else {
            print("Error: Payment is already deleted")
            return
        }
        
        // Extract billId while payment object is still valid
        guard let savedBillId = payment.billId else {
            print("Error: Payment has no billId")
            return
        }
        
        let context = coreDataManager.viewContext
        
        // Delete the payment
        context.delete(payment)
        
        // Save the deletion using CoreDataManager's save method
        coreDataManager.save()
        
        // Now fetch payments using the saved billId (payment object is deleted, can't access it)
        fetchPayments(for: savedBillId)
        fetchAllPayments() // Refresh all payments for dashboard
        
        // Reschedule notifications for the bill since payment was removed
        // Fetch the bill separately to avoid accessing deleted relationship
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", savedBillId as CVarArg)
        request.fetchLimit = 1
        
        do {
            if let bill = try context.fetch(request).first {
                NotificationManager.shared.cancelNotifications(for: bill.id)
                Task {
                    // Ensure authorization is granted
                    let authorized = await NotificationManager.shared.requestAuthorization()
                    if authorized {
                        NotificationManager.shared.scheduleBillReminder(for: bill, daysBefore: [1, 3, 7])
                        NotificationManager.shared.scheduleOverdueAlert(for: bill)
                    }
                }
            }
        } catch {
            print("Error fetching bill for notification rescheduling: \(error)")
        }
    }
    
    // MARK: - Unmark Bill as Paid
    func unmarkBillAsPaid(_ bill: Bill) {
        if let payment = paymentForCurrentPeriod(for: bill) {
            deletePayment(payment)
        }
    }
    
    // MARK: - Total Paid for Month
    func totalPaidForMonth(for month: Date) -> Double {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return payments.filter { payment in
            let paymentDate = payment.datePaid
            return paymentDate >= startOfMonth && paymentDate <= endOfMonth
        }.reduce(0) { $0 + $1.amount }
    }
    
    /// All individual payments for a given calendar month.
    func paymentsForMonth(_ month: Date) -> [Payment] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return payments.filter { payment in
            let paymentDate = payment.datePaid
            return paymentDate >= startOfMonth && paymentDate <= endOfMonth
        }
        .sorted { $0.datePaid > $1.datePaid }
    }
    
    // MARK: - Observers
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.fetchAllPayments()
            }
            .store(in: &cancellables)
    }
    
}

