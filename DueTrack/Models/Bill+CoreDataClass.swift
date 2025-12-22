import Foundation
import CoreData

@objc(Bill)
public class Bill: NSManagedObject {
    
}

extension Bill {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Bill> {
        return NSFetchRequest<Bill>(entityName: "Bill")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var name: String
    @NSManaged public var amount: Double
    @NSManaged public var dueDay: Int32
    @NSManaged public var frequency: String
    @NSManaged public var category: String
    @NSManaged public var isAutoPay: Bool
    @NSManaged public var isActive: Bool
    @NSManaged public var createdDate: Date?
    @NSManaged public var notes: String?
    @NSManaged public var payments: NSSet?
    @NSManaged public var customInterval: Int32
    @NSManaged public var customUnit: String?
    
    // Computed property for next due date
    public var nextDueDate: Date {
        let freq = BillFrequency(rawValue: frequency) ?? .monthly
        let calendar = Calendar.current
        let today = Date()
        let paymentsSet = (payments as? Set<Payment>) ?? []
        let paymentsArray = Array(paymentsSet)
        let customIntervalValue = freq == .custom && customInterval > 0 ? Int(customInterval) : nil
        let customUnitValue = freq == .custom ? CustomRecurrenceUnit(rawValue: customUnit ?? "") : nil
        
        var candidate = createdDate ?? Date()
        var safetyCounter = 0
        
        // Advance through occurrences until we find the first unpaid one
        while safetyCounter < 1000 {
            let isPaid = DateHelpers.isOccurrencePaid(
                occurrenceDate: candidate,
                frequency: freq,
                payments: paymentsArray,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            
            if !isPaid {
                // This is the next unpaid occurrence (may be in the past = overdue)
                return candidate
            }
            
            let next = DateHelpers.nextOccurrence(
                from: candidate,
                frequency: freq,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            // Safety: break if next didn't advance
            if next <= candidate {
                break
            }
            candidate = next
            safetyCounter += 1
        }
        
        // Fallback: if something goes wrong, treat today as next due
        return max(candidate, today)
    }
    
    // Computed property for payment status
    public var paymentStatus: PaymentStatus {
        let calendar = Calendar.current
        let today = Date()
        let freq = BillFrequency(rawValue: frequency) ?? .monthly
        let paymentsSet = (payments as? Set<Payment>) ?? []
        let paymentsArray = Array(paymentsSet)
        let customIntervalValue = freq == .custom && customInterval > 0 ? Int(customInterval) : nil
        let customUnitValue = freq == .custom ? CustomRecurrenceUnit(rawValue: customUnit ?? "") : nil
        
        // 1. Check for any unpaid occurrence in the past → Overdue
        var occurrence = createdDate ?? Date()
        var safetyCounter = 0
        while occurrence < today && safetyCounter < 1000 {
            let isPaid = DateHelpers.isOccurrencePaid(
                occurrenceDate: occurrence,
                frequency: freq,
                payments: paymentsArray,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            
            if !isPaid {
                return .overdue
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
        
        // At this point, all past occurrences are paid (or none exist).
        // Determine "current period" occurrence on or before today.
        var lastOccurrenceOnOrBeforeToday = createdDate ?? Date()
        occurrence = createdDate ?? Date()
        safetyCounter = 0
        while occurrence <= today && safetyCounter < 1000 {
            lastOccurrenceOnOrBeforeToday = occurrence
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
        
        let currentPeriodPaid = DateHelpers.isOccurrencePaid(
            occurrenceDate: lastOccurrenceOnOrBeforeToday,
            frequency: freq,
            payments: paymentsArray,
            customInterval: customIntervalValue,
            customUnit: customUnitValue
        )
        
        if currentPeriodPaid {
            return .paid
        }
        
        // 2. Upcoming vs Future based on next unpaid occurrence after today
        var nextUnpaid = occurrence // first occurrence > today from earlier loop or today if equal
        safetyCounter = 0
        while safetyCounter < 1000 {
            let isPaid = DateHelpers.isOccurrencePaid(
                occurrenceDate: nextUnpaid,
                frequency: freq,
                payments: paymentsArray,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            
            if !isPaid {
                break
            }
            
            let next = DateHelpers.nextOccurrence(
                from: nextUnpaid,
                frequency: freq,
                customInterval: customIntervalValue,
                customUnit: customUnitValue
            )
            if next <= nextUnpaid {
                break
            }
            nextUnpaid = next
            safetyCounter += 1
        }
        
        let daysUntil = calendar.dateComponents([.day], from: today, to: nextUnpaid).day ?? 0
        if daysUntil <= 7 && daysUntil >= 0 {
            return .upcoming
        }
        
        return .future
    }
}

// MARK: - Generated accessors for payments
extension Bill {
    
    @objc(addPaymentsObject:)
    @NSManaged public func addToPayments(_ value: Payment)
    
    @objc(removePaymentsObject:)
    @NSManaged public func removeFromPayments(_ value: Payment)
    
    @objc(addPayments:)
    @NSManaged public func addToPayments(_ values: NSSet)
    
    @objc(removePayments:)
    @NSManaged public func removeFromPayments(_ values: NSSet)
}

// MARK: - Enums
public enum CustomRecurrenceUnit: String {
    case days = "days"
    case weeks = "weeks"
    case months = "months"
    case years = "years"
}

public enum BillFrequency: String, CaseIterable {
    case weekly = "weekly"
    case biWeekly = "bi-weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case annual = "annual"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biWeekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .annual: return "Annual"
        case .custom: return "Custom"
        }
    }
}

public enum BillCategory: String, CaseIterable {
    case utilities = "Utilities"
    case subscriptions = "Subscriptions"
    case loans = "Loans"
    case insurance = "Insurance"
    case rent = "Rent"
    case creditCard = "Credit Card"
    case other = "Other"
    
    public var icon: String {
        switch self {
        case .utilities: return "bolt.fill"
        case .subscriptions: return "play.rectangle.fill"
        case .loans: return "banknote.fill"
        case .insurance: return "shield.fill"
        case .rent: return "house.fill"
        case .creditCard: return "creditcard.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    /// User-facing name (keeps stored raw values stable while updating labels)
    public var displayName: String {
        switch self {
        case .utilities: return "Utilities"
        case .subscriptions: return "Subscriptions"
        case .loans: return "Loans"
        case .insurance: return "Insurance"
        case .rent: return "Home"
        case .creditCard: return "Credit Card"
        case .other: return "Other"
        }
    }
    
    /// Hex color used for category-based visuals (e.g., calendar dots)
    public var colorHex: String {
        switch self {
        case .utilities: return "#3B82F6"    // Blue
        case .subscriptions: return "#8B5CF6" // Purple
        case .loans: return "#EC4899"        // Pink
        case .insurance: return "#10B981"    // Green
        case .rent: return "#F97316"         // Orange (Home)
        case .creditCard: return "#F59E0B"   // Amber
        case .other: return "#6B7280"        // Gray
        }
    }
}

public enum PaymentStatus: Equatable {
    case paid
    case overdue
    case upcoming
    case future
    
    public var color: String {
        switch self {
        case .paid: return "#10B981" // Mint green
        case .overdue: return "#EF4444" // Red
        case .upcoming: return "#F59E0B" // Yellow/Amber
        case .future: return "#6B7280" // Gray
        }
    }
}

