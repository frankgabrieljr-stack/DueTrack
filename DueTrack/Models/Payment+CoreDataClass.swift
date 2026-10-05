import Foundation
import CoreData

@objc(Payment)
public class Payment: NSManagedObject {
    
}

extension Payment {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Payment> {
        return NSFetchRequest<Payment>(entityName: "Payment")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var billId: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var datePaid: Date
    @NSManaged public var dueDate: Date?
    @NSManaged public var isPaid: Bool
    @NSManaged public var notes: String?
    @NSManaged public var bill: Bill?

    public var effectiveDueDate: Date {
        dueDate ?? datePaid
    }

    /// Scheduled bill date this payment applies to.
    /// A payment saved on the day it was paid still covers the occurrence it fell after.
    public var coveredScheduledDueDate: Date {
        guard let bill else { return effectiveDueDate }
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return DateHelpers.scheduledOccurrence(
            containing: effectiveDueDate,
            startDate: bill.createdDate ?? effectiveDueDate,
            frequency: frequency,
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )
    }

    public var wasPaidLate: Bool {
        Calendar.current.startOfDay(for: datePaid) > Calendar.current.startOfDay(for: coveredScheduledDueDate)
    }
}

