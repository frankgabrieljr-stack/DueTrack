import Foundation
import CoreData
import Combine

class BillViewModel: ObservableObject {
    @Published var bills: [Bill] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        fetchBills()
        setupNotificationObservers()
    }
    
    // MARK: - Fetch Bills
    func fetchBills() {
        isLoading = true
        let request: NSFetchRequest<Bill> = Bill.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Bill.dueDay, ascending: true)]
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            bills = try coreDataManager.viewContext.fetch(request)
            isLoading = false
            // Update widget snapshots whenever bills are refreshed
            WidgetDataManager.updateNextBillSnapshot(from: bills)
            WidgetDataManager.updateThisWeekSnapshot(from: billsDueInNextWeek())
        } catch {
            errorMessage = "Failed to fetch bills: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Create Bill
    func createBill(
        name: String,
        amount: Double,
        startDate: Date,
        dueDay: Int,
        frequency: BillFrequency,
        category: BillCategory,
        isAutoPay: Bool,
        notes: String?,
        customInterval: Int?,
        customUnit: CustomRecurrenceUnit?
    ) -> Bool {
        let context = coreDataManager.viewContext
        let bill = Bill(context: context)
        
        bill.id = UUID()
        bill.name = name
        bill.amount = amount
        bill.dueDay = Int32(dueDay)
        bill.frequency = frequency.rawValue
        bill.category = category.rawValue
        bill.isAutoPay = isAutoPay
        bill.isActive = true
        // Use startDate as createdDate so we can track when the bill actually starts
        bill.createdDate = startDate
        bill.notes = notes
        if frequency == .custom {
            bill.customInterval = Int32(customInterval ?? 0)
            bill.customUnit = customUnit?.rawValue
        } else {
            bill.customInterval = 0
            bill.customUnit = nil
        }
        
        let saved = coreDataManager.save()
        if saved {
        fetchBills()
        
        // Schedule notifications
        Task {
            let authorized = await NotificationManager.shared.requestAuthorization()
            if authorized {
                NotificationManager.shared.scheduleBillReminder(for: bill, daysBefore: [1, 3, 7])
                NotificationManager.shared.scheduleOverdueAlert(for: bill)
            }
        }
        } else {
            errorMessage = "Failed to save bill. Please try again."
            context.delete(bill)
        }
        
        return saved
    }
    
    // MARK: - Update Bill
    func updateBill(_ bill: Bill) -> Bool {
        let saved = coreDataManager.save()
        if saved {
        fetchBills()
        
        // Reschedule notifications
        if let id = bill.id {
            NotificationManager.shared.cancelNotifications(for: id)
        }
        Task {
            // Ensure authorization is granted
            let authorized = await NotificationManager.shared.requestAuthorization()
            if authorized {
                NotificationManager.shared.scheduleBillReminder(for: bill, daysBefore: [1, 3, 7])
                NotificationManager.shared.scheduleOverdueAlert(for: bill)
            }
        }
        } else {
            errorMessage = "Failed to update bill. Please try again."
        }
        return saved
    }
    
    // MARK: - Delete Bill
    func deleteBill(_ bill: Bill) -> Bool {
        if let id = bill.id {
            NotificationManager.shared.cancelNotifications(for: id)
        }
        
        let context = coreDataManager.viewContext
        context.delete(bill)
        let saved = coreDataManager.save()
        if saved {
        fetchBills()
        } else {
            errorMessage = "Failed to delete bill. Please try again."
            context.rollback()
        }
        return saved
    }
    
    // MARK: - Get Bills by Status
    func billsByStatus(_ status: PaymentStatus) -> [Bill] {
        return bills.filter { $0.paymentStatus == status }
    }
    
    func upcomingBills() -> [Bill] {
        return bills.filter { bill in
            let status = bill.paymentStatus
            return status == .upcoming || status == .overdue
        }
    }
    
    // MARK: - Statistics
    func totalMonthlyOutflow(for month: Date = Date()) -> Double {
        return bills.reduce(0) { total, bill in
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )
            // Multiply amount by number of occurrences in the month
            return total + (bill.amount * Double(occurrences.count))
        }
    }
    
    /// Get all bill occurrences for a specific date
    func billOccurrences(for date: Date) -> [(bill: Bill, occurrenceDate: Date)] {
        var results: [(bill: Bill, occurrenceDate: Date)] = []
        let calendar = Calendar.current
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        
        for bill in bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )
            
            for occurrenceDate in occurrences {
                if calendar.isDate(occurrenceDate, inSameDayAs: date) {
                    results.append((bill: bill, occurrenceDate: occurrenceDate))
                }
            }
        }
        
        return results
    }
    
    func overdueAmount() -> Double {
        return billsByStatus(.overdue).reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Bills Due in Next Week
    func billsDueInNextWeek() -> [(bill: Bill, nextDueDate: Date)] {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
        
        var results: [(bill: Bill, nextDueDate: Date)] = []
        
        for bill in bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let month = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )
            
            // Find the next occurrence within the next 7 days (inclusive), comparing by day
            for occurrenceDate in occurrences {
                let day = calendar.startOfDay(for: occurrenceDate)
                if day >= startOfToday && day <= nextWeek {
                    results.append((bill: bill, nextDueDate: day))
                    break // Only add the first occurrence in the range
                }
            }
            
            // Also check next month if needed
            if results.last?.bill.id != bill.id {
                let nextMonth = calendar.date(byAdding: .month, value: 1, to: month)!
                let nextMonthOccurrences = DateHelpers.occurrencesForMonth(
                    startDate: startDate,
                    frequency: frequency,
                    customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                    customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                    for: nextMonth
                )
                
                for occurrenceDate in nextMonthOccurrences {
                    let day = calendar.startOfDay(for: occurrenceDate)
                    if day >= startOfToday && day <= nextWeek {
                        results.append((bill: bill, nextDueDate: day))
                        break
                    }
                }
            }
        }
        
        // Sort by due date
        return results.sorted { $0.nextDueDate < $1.nextDueDate }
    }
    
    // MARK: - Filtering Methods for Detail Views
    func monthlyBills() -> [Bill] {
        return bills.filter { bill in
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            return frequency == .monthly || frequency == .biWeekly || frequency == .weekly
        }
    }
    
    func overdueBills() -> [Bill] {
        return billsByStatus(.overdue)
    }
    
    func upcomingBillsWithinDays(_ days: Int = 30) -> [Bill] {
        let calendar = Calendar.current
        let today = Date()
        let futureDate = calendar.date(byAdding: .day, value: days, to: today) ?? today
        
        return bills.filter { bill in
            let nextDue = bill.nextDueDate
            let status = bill.paymentStatus
            return (status == .upcoming || status == .overdue) && nextDue <= futureDate
        }.sorted { $0.nextDueDate < $1.nextDueDate }
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                self?.fetchBills()
            }
            .store(in: &cancellables)
    }
}

