import Foundation
import CloudKit

class CloudKitSyncManager {
    static let shared = CloudKitSyncManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    
    init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Sync Bill to CloudKit
    func syncBill(_ bill: Bill) async throws {
        // Safely unwrap the bill's id; if it's missing, skip syncing this record
        // instead of crashing when accessing uuidString.
        guard let billId = bill.id else {
            print("CloudKitSyncManager: Bill has no id, skipping sync.")
            return
        }
        
        let record = CKRecord(
            recordType: "Bill",
            recordID: CKRecord.ID(recordName: billId.uuidString)
        )
        
        record["name"] = bill.name
        record["amount"] = bill.amount
        record["dueDay"] = bill.dueDay
        record["frequency"] = bill.frequency
        record["category"] = bill.category
        record["isAutoPay"] = bill.isAutoPay
        record["isActive"] = bill.isActive
        record["createdDate"] = bill.createdDate ?? Date()
        record["notes"] = bill.notes
        
        try await privateDatabase.save(record)
    }
    
    // MARK: - Sync Payment to CloudKit
    func syncPayment(_ payment: Payment) async throws {
        let record = CKRecord(recordType: "Payment", recordID: CKRecord.ID(recordName: payment.id.uuidString))
        
        if let billId = payment.billId {
            record["billId"] = billId.uuidString
        }
        record["amount"] = payment.amount
        record["datePaid"] = payment.datePaid
        record["isPaid"] = payment.isPaid
        record["notes"] = payment.notes
        
        try await privateDatabase.save(record)
    }
    
    // MARK: - Fetch from CloudKit
    func fetchBills() async throws -> [CKRecord] {
        let query = CKQuery(recordType: "Bill", predicate: NSPredicate(value: true))
        let result = try await privateDatabase.records(matching: query)
        return Array(result.matchResults.compactMap { try? $0.1.get() })
    }
}

