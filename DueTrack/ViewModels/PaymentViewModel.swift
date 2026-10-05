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
        fetchAllPayments()
    }
    
    // MARK: - Fetch Payments
    /// Always loads the full payments list. Bill-specific filtering belongs in `paymentHistory(for:)`.
    func fetchPayments(for billId: UUID? = nil) {
        // NOTE: Intentionally ignores billId for the published array so opening one bill
        // never wipes payment state used by Dashboard / Bills / Insights.
        fetchAllPayments()
    }
    
    // MARK: - Fetch All Payments
    func fetchAllPayments() {
        let request: NSFetchRequest<Payment> = Payment.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Payment.datePaid, ascending: false)]
        
        do {
            payments = try coreDataManager.viewContext.fetch(request)
        } catch {
            print("Error fetching payments: \(error)")
        }
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
            fetchAllPayments()
            
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
        let occurrence = scheduledOccurrenceDate(for: bill, containing: occurrenceDate)
        // Prevent duplicate payments for the same occurrence, including a payment
        // that was saved on the day it was paid instead of the real due date.
        if paymentExists(for: bill, on: occurrence) != nil {
            return true
        }
        return createPayment(for: bill, amount: paymentAmount, datePaid: datePaid, dueDate: occurrence, notes: notes)
    }
    
    // MARK: - Get Payment History for Bill
    func paymentHistory(for bill: Bill) -> [Payment] {
        var history = bill.resolvedPayments

        if let billId = bill.id {
            for payment in payments where payment.billId == billId {
                if !history.contains(where: { $0.objectID == payment.objectID }) {
                    history.append(payment)
                }
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
        let occurrence = currentPeriodOccurrenceDate(for: bill)
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return DateHelpers.matchingPayment(
            for: occurrence,
            frequency: frequency,
            payments: paymentHistory(for: bill),
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )
    }

    /// Returns an existing payment that matches the given date (same day), if any.
    func paymentExists(for bill: Bill, on date: Date) -> Payment? {
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        let occurrence = scheduledOccurrenceDate(for: bill, containing: date)
        return DateHelpers.matchingPayment(
            for: occurrence,
            frequency: frequency,
            payments: paymentHistory(for: bill),
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )
    }

    private func scheduledOccurrenceDate(for bill: Bill, containing date: Date) -> Date {
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return DateHelpers.scheduledOccurrence(
            containing: date,
            startDate: bill.createdDate ?? date,
            frequency: frequency,
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )
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
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return DateHelpers.unpaidOverdueOccurrences(
            startDate: bill.createdDate ?? date,
            frequency: frequency,
            payments: paymentHistory(for: bill),
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
            upTo: date
        )
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
        
        // Now refresh using the saved billId (payment object is deleted, can't access it)
        fetchAllPayments()
        
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
        if bill.id == nil {
            bill.id = UUID()
        }

        let overdueOccurrences = unpaidOverdueOccurrences(for: bill)
        guard !overdueOccurrences.isEmpty else {
            return true
        }

        let paymentAmount = amount ?? bill.amount
        let context = coreDataManager.viewContext
        let calendar = Calendar.current

        for occurrence in overdueOccurrences {
            // Skip if a payment for this due date already exists
            if paymentExists(for: bill, on: occurrence) != nil {
                continue
            }

            let payment = Payment(context: context)
            payment.id = UUID()
            payment.billId = bill.id
            payment.amount = paymentAmount
            payment.datePaid = datePaid
            payment.dueDate = calendar.startOfDay(for: occurrence)
            payment.isPaid = true
            payment.notes = notes
            payment.bill = bill
        }

        let saved = coreDataManager.save()
        if saved {
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
        paymentsForMonth(month).reduce(0) { partial, payment in
            let cap = payment.bill?.amount ?? payment.amount
            return partial + min(payment.amount, cap)
        }
    }
    
    /// One row per scheduled occurrence in the month.
    /// A second payment for the same due date does not increase the total.
    func paymentsForMonth(_ month: Date) -> [Payment] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        let inMonth = payments.filter { payment in
            let paymentDate = payment.datePaid
            return paymentDate >= startOfMonth && paymentDate < startOfNextMonth
        }
        
        var chosen: [String: Payment] = [:]
        for payment in inMonth {
            let key = occurrenceKey(for: payment)
            if let existing = chosen[key] {
                if payment.datePaid > existing.datePaid {
                    chosen[key] = payment
                }
            } else {
                chosen[key] = payment
            }
        }
        
        return chosen.values.sorted { $0.datePaid > $1.datePaid }
    }

    private func occurrenceKey(for payment: Payment) -> String {
        let due = payment.coveredScheduledDueDate
        let day = Calendar.current.startOfDay(for: due).timeIntervalSince1970
        let billKey = payment.billId?.uuidString ?? payment.bill?.id?.uuidString ?? payment.id.uuidString
        return "\(billKey)-\(day)"
    }
    
    // MARK: - Observers
    private func setupObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchAllPayments()
            }
            .store(in: &cancellables)
    }
    
}

