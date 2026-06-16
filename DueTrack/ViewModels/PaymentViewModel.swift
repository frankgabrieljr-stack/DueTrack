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
        dueDate: Date? = nil,
        notes: String? = nil
    ) -> Bool {
        let context = coreDataManager.viewContext
        let payment = Payment(context: context)
        
        if bill.id == nil {
            bill.id = UUID()
        }

        payment.id = UUID()
        payment.billId = bill.id
        payment.amount = amount
        payment.datePaid = datePaid
        payment.dueDate = dueDate ?? datePaid
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
        let dueDate = nextUnpaidOccurrenceDate(for: bill) ?? currentPeriodOccurrenceDate(for: bill)
        // Prevent duplicate payments for the current period
        if paymentExists(for: bill, on: dueDate) != nil {
            return true
        }
        return createPayment(for: bill, amount: paymentAmount, datePaid: Date(), dueDate: dueDate, notes: notes)
    }
    
    /// Mark a specific bill occurrence (for a given due date) as paid.
    /// This is useful when marking a past calendar date as paid.
    func markBillAsPaid(
        _ bill: Bill,
        on occurrenceDate: Date,
        paidOn datePaid: Date = Date(),
        amount: Double? = nil,
        notes: String? = nil
    ) -> Bool {
        let paymentAmount = amount ?? bill.amount
        // Prevent duplicate payments for the same occurrence date
        if paymentExists(for: bill, on: occurrenceDate) != nil {
            return true
        }
        return createPayment(for: bill, amount: paymentAmount, datePaid: datePaid, dueDate: occurrenceDate, notes: notes)
    }
    
    // MARK: - Get Payment History for Bill
    func paymentHistory(for bill: Bill) -> [Payment] {
        guard let billId = bill.id else {
            return []
        }

        var history: [Payment] = payments.compactMap { payment in
            guard payment.billId == billId else { return nil }
            return payment
        }

        let relationshipPayments = (bill.payments as? Set<Payment>) ?? []
        for payment in relationshipPayments {
            if !history.contains(where: { $0.id == payment.id }) {
                history.append(payment)
            }
        }

        return history.sorted { $0.datePaid > $1.datePaid }
    }
    
    // MARK: - Total Paid for Bill
    func totalPaid(for bill: Bill) -> Double {
        return paymentHistory(for: bill).reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Is Bill Paid
    func isBillPaid(_ bill: Bill) -> Bool {
        let occurrence = currentPeriodOccurrenceDate(for: bill)
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return DateHelpers.isOccurrencePaid(
            occurrenceDate: occurrence,
            frequency: frequency,
            payments: paymentHistory(for: bill),
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )
    }
    
    // MARK: - Get Payment for Current Period
    func paymentForCurrentPeriod(for bill: Bill) -> Payment? {
        let calendar = Calendar.current
        let occurrence = currentPeriodOccurrenceDate(for: bill)
        return paymentHistory(for: bill).first { payment in
            calendar.isDate(payment.effectiveDueDate, inSameDayAs: occurrence)
        }
    }

    /// Returns an existing payment that matches the given date (same day), if any.
    func paymentExists(for bill: Bill, on date: Date) -> Payment? {
        let calendar = Calendar.current
        return paymentHistory(for: bill).first { payment in
            calendar.isDate(payment.effectiveDueDate, inSameDayAs: date)
        }
    }

    private func nextUnpaidOccurrenceDate(for bill: Bill, asOf date: Date = Date()) -> Date? {
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        let startDate = bill.createdDate ?? date
        let customIntervalValue = frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil
        let customUnitValue = frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        let payments = paymentHistory(for: bill)

        var occurrence = Calendar.current.startOfDay(for: startDate)
        var safetyCounter = 0

        while safetyCounter < 1000 {
            let isPaid = DateHelpers.isOccurrencePaid(
                occurrenceDate: occurrence,
                frequency: frequency,
                payments: payments,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )

            if !isPaid {
                return occurrence
            }

            let next = DateHelpers.nextOccurrence(
                from: occurrence,
                frequency: frequency,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            if next <= occurrence {
                break
            }
            occurrence = Calendar.current.startOfDay(for: next)
            safetyCounter += 1
        }

        return nil
    }

    private func currentPeriodOccurrenceDate(for bill: Bill, asOf date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        let startDate = bill.createdDate ?? date
        let customIntervalValue = frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil
        let customUnitValue = frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil

        var occurrence = calendar.startOfDay(for: startDate)
        var lastOccurrence = occurrence
        var safetyCounter = 0

        while occurrence <= date && safetyCounter < 1000 {
            lastOccurrence = occurrence
            let next = DateHelpers.nextOccurrence(
                from: occurrence,
                frequency: frequency,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            if next <= occurrence {
                break
            }
            occurrence = calendar.startOfDay(for: next)
            safetyCounter += 1
        }

        return lastOccurrence
    }

    /// Unpaid occurrences before today (overdue).
    func unpaidOverdueOccurrences(for bill: Bill, upTo date: Date = Date()) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        let startDate = bill.createdDate ?? today
        let customIntervalValue = frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil
        let customUnitValue = frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        let payments = paymentHistory(for: bill)

        var occurrences: [Date] = []
        var occurrence = calendar.startOfDay(for: startDate)
        var safetyCounter = 0

        while occurrence < today && safetyCounter < 1000 {
            let isPaid = DateHelpers.isOccurrencePaid(
                occurrenceDate: occurrence,
                frequency: frequency,
                payments: payments,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )

            if !isPaid {
                occurrences.append(occurrence)
            }

            let next = DateHelpers.nextOccurrence(
                from: occurrence,
                frequency: frequency,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            if next <= occurrence {
                break
            }
            occurrence = calendar.startOfDay(for: next)
            safetyCounter += 1
        }

        return occurrences
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
        _ = coreDataManager.save()
        
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

    // MARK: - Mark All Overdue Occurrences as Paid
    func markAllOverdueAsPaid(
        _ bill: Bill,
        paidOn datePaid: Date = Date(),
        amount: Double? = nil,
        notes: String? = nil
    ) -> Bool {
        let overdueOccurrences = unpaidOverdueOccurrences(for: bill)
        guard !overdueOccurrences.isEmpty else {
            return true
        }

        let paymentAmount = amount ?? bill.amount
        let context = coreDataManager.viewContext

        for occurrence in overdueOccurrences {
            let payment = Payment(context: context)
            payment.id = UUID()
            payment.billId = bill.id
            payment.amount = paymentAmount
            payment.datePaid = datePaid
            payment.dueDate = occurrence
            payment.isPaid = true
            payment.notes = notes
            payment.bill = bill
        }

        let saved = coreDataManager.save()
        if saved {
            fetchPayments(for: bill.id)
            fetchAllPayments()

            if let billId = bill.id {
                NotificationManager.shared.cancelNotifications(for: billId)
            }
            Task {
                let authorized = await NotificationManager.shared.requestAuthorization()
                if authorized {
                    NotificationManager.shared.scheduleBillReminder(for: bill, daysBefore: [1, 3, 7])
                    NotificationManager.shared.scheduleOverdueAlert(for: bill)
                }
            }
        } else {
            context.rollback()
        }

        return saved
    }

    // MARK: - Update Payment
    func updatePayment(_ payment: Payment, amount: Double, datePaid: Date, dueDate: Date, notes: String?) -> Bool {
        payment.amount = amount
        payment.datePaid = datePaid
        payment.dueDate = dueDate
        payment.notes = notes

        let saved = coreDataManager.save()
        if saved {
            if let billId = payment.billId {
                fetchPayments(for: billId)
            }
            fetchAllPayments()

            if let billId = payment.billId {
                let context = coreDataManager.viewContext
                let request: NSFetchRequest<Bill> = Bill.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", billId as CVarArg)
                request.fetchLimit = 1
                if let bill = try? context.fetch(request).first {
                    NotificationManager.shared.cancelNotifications(for: bill.id)
                    Task {
                        let authorized = await NotificationManager.shared.requestAuthorization()
                        if authorized {
                            NotificationManager.shared.scheduleBillReminder(for: bill, daysBefore: [1, 3, 7])
                            NotificationManager.shared.scheduleOverdueAlert(for: bill)
                        }
                    }
                }
            }
        }

        return saved
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
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return payments.filter { payment in
            let paymentDate = payment.datePaid
            return paymentDate >= startOfMonth && paymentDate < startOfNextMonth
        }.reduce(0) { $0 + $1.amount }
    }
    
    /// All individual payments for a given calendar month.
    func paymentsForMonth(_ month: Date) -> [Payment] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        return payments.filter { payment in
            let paymentDate = payment.datePaid
            return paymentDate >= startOfMonth && paymentDate < startOfNextMonth
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

