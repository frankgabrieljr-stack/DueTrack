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
    @NSManaged public var isPaid: Bool
    @NSManaged public var notes: String?
    @NSManaged public var bill: Bill?
}

