import Foundation

/// Data model used for sharing "next bill" info with a Widget via App Group.
struct NextBillSnapshot: Codable {
    let billId: UUID?
    let name: String
    let amount: Double
    let dueDate: Date
    let isOverdue: Bool
}

/// Data model used for sharing "bills due this week" info with a Widget via App Group.
struct WeekBillSnapshot: Codable {
    let billId: UUID?
    let name: String
    let amount: Double
    let dueDate: Date
    let isOverdue: Bool
    let category: String
    /// Whether this specific occurrence has been marked paid.
    /// Optional for backward compatibility with older stored snapshots.
    let isPaid: Bool?
}

enum WidgetDataManager {
    /// IMPORTANT: Set this to the same App Group identifier you configure in Xcode
    /// for both the main app and the widget extension.
    private static let appGroupId = "group.com.frankg.DueTrack"
    private static let nextBillKey = "nextBillSnapshot"
    private static let thisWeekKey = "thisWeekSnapshot"
    
    /// Compute and store the current "next bill" snapshot for widgets.
    static func updateNextBillSnapshot(from bills: [Bill]) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return
        }
        
        // Find the next bill occurrence: prioritize overdue, then upcoming, then future.
        let sorted = bills.sorted { lhs, rhs in
            lhs.nextDueDate < rhs.nextDueDate
        }
        
        guard let nextBill = sorted.first else {
            defaults.removeObject(forKey: nextBillKey)
            return
        }
        
        let frequency = BillFrequency(rawValue: nextBill.frequency) ?? .monthly
        let isOverdue = !DateHelpers.unpaidOverdueOccurrences(
            startDate: nextBill.createdDate ?? Date(),
            frequency: frequency,
            payments: nextBill.resolvedPayments,
            customInterval: frequency == .custom && nextBill.customInterval > 0 ? Int(nextBill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: nextBill.customUnit ?? "") : nil
        ).isEmpty

        let snapshot = NextBillSnapshot(
            billId: nextBill.id,
            name: nextBill.name,
            amount: nextBill.amount,
            dueDate: nextBill.nextDueDate,
            isOverdue: isOverdue
        )
        
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: nextBillKey)
        } catch {
            print("Failed to encode NextBillSnapshot: \(error)")
        }
    }
    
    /// For use in the widget extension to read the latest snapshot.
    static func loadNextBillSnapshot() -> NextBillSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let data = defaults.data(forKey: nextBillKey)
        else {
            return nil
        }
        
        return try? JSONDecoder().decode(NextBillSnapshot.self, from: data)
    }
    
    /// Compute and store the "bills due in the next 7 days" snapshot for widgets.
    static func updateThisWeekSnapshot(from items: [(bill: Bill, nextDueDate: Date)]) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else {
            return
        }
        
        // Map to lightweight snapshot models, limit to first 5 for widget
        let snapshots: [WeekBillSnapshot] = items
            .sorted { $0.nextDueDate < $1.nextDueDate }
            .prefix(5)
            .map { pair in
                let frequency = BillFrequency(rawValue: pair.bill.frequency) ?? .monthly
                let paidForDate = isBillPaidForDate(pair.bill, dueDate: pair.nextDueDate)
                let isOverdue = !DateHelpers.unpaidOverdueOccurrences(
                    startDate: pair.bill.createdDate ?? Date(),
                    frequency: frequency,
                    payments: pair.bill.resolvedPayments,
                    customInterval: frequency == .custom && pair.bill.customInterval > 0 ? Int(pair.bill.customInterval) : nil,
                    customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: pair.bill.customUnit ?? "") : nil
                ).isEmpty
                
                return WeekBillSnapshot(
                    billId: pair.bill.id,
                    name: pair.bill.name,
                    amount: pair.bill.amount,
                    dueDate: pair.nextDueDate,
                    isOverdue: isOverdue,
                    category: pair.bill.category,
                    isPaid: paidForDate
                )
            }
        
        if snapshots.isEmpty {
            defaults.removeObject(forKey: thisWeekKey)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(snapshots)
            defaults.set(data, forKey: thisWeekKey)
        } catch {
            print("Failed to encode WeekBillSnapshot array: \(error)")
        }
    }
    
    /// For use in the widget extension to read the "this week" snapshot.
    static func loadThisWeekSnapshot() -> [WeekBillSnapshot]? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let data = defaults.data(forKey: thisWeekKey)
        else {
            return nil
        }
        
        return try? JSONDecoder().decode([WeekBillSnapshot].self, from: data)
    }

    /// Helper: check if a given bill occurrence (for a specific due date) has been paid.
    private static func isBillPaidForDate(_ bill: Bill, dueDate: Date) -> Bool {
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return DateHelpers.isOccurrencePaid(
            occurrenceDate: dueDate,
            frequency: frequency,
            payments: bill.resolvedPayments,
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )
    }
}


