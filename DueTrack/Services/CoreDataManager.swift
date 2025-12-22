import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DueTrack")
        
        // Enable CloudKit if needed
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { description, error in
            if let error = error {
                // Log error instead of crashing
                print("❌ Core Data store failed to load: \(error.localizedDescription)")
                // In production, you might want to show an alert or attempt recovery
                // For now, we'll log and continue - the app will show empty state
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Save Context
    func save() -> Bool {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
                return true
            } catch {
                let nsError = error as NSError
                print("❌ Core Data save failed: \(nsError.localizedDescription)")
                print("   Error details: \(nsError.userInfo)")
                // Rollback changes on error
                context.rollback()
                return false
            }
        }
        return true
    }
    
    // MARK: - Save with Error Handling
    func saveWithError() throws {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Background Context
    func newBackgroundContext() -> NSManagedObjectContext {
        return persistentContainer.newBackgroundContext()
    }
}

