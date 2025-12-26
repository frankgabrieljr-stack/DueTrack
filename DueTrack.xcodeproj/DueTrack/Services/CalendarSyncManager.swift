import Foundation
import EventKit
import CoreData

/// Handles syncing bill due dates into the native Calendar app using EventKit.
enum CalendarSyncManager {
    private static let eventStore = EKEventStore()
    private static let calendarIdentifierKey = "DueTrackCalendarIdentifier"

    /// Whether the user has enabled calendar sync.
    static var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "calendarSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "calendarSyncEnabled") }
    }

    /// Request access and, if granted, ensure the DueTrack calendar exists.
    static func requestAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            return ensureCalendarExists() != nil
        case .notDetermined:
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                if granted {
                    return ensureCalendarExists() != nil
                }
                return false
            } catch {
                print("CalendarSyncManager: requestAccess failed: \(error)")
                return false
            }
        default:
            return false
        }
    }

    /// Create or fetch the dedicated DueTrack calendar.
    @discardableResult
    private static func ensureCalendarExists() -> EKCalendar? {
        if let id = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let existing = eventStore.calendar(withIdentifier: id) {
            return existing
        }

        guard let source = eventStore.defaultCalendarForNewEvents?.source ??
                eventStore.sources.first(where: { $0.sourceType == .local }) else {
            return nil
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "DueTrack Bills"
        calendar.source = source

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
            return calendar
        } catch {
            print("CalendarSyncManager: failed to save calendar: \(error)")
            return nil
        }
    }

    /// Remove all events from the DueTrack calendar and delete the calendar itself.
    /// Used when the user turns calendar sync OFF.
    static func clearCalendar() {
        guard let id = UserDefaults.standard.string(forKey: calendarIdentifierKey),
              let calendar = eventStore.calendar(withIdentifier: id) else {
            return
        }

        let store = eventStore
        let predicate = store.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]
        )

        let events = store.events(matching: predicate)
        events.forEach { event in
            do {
                try store.remove(event, span: .thisEvent, commit: false)
            } catch {
                print("CalendarSyncManager: failed to remove event during clear: \(error)")
            }
        }

        do {
            try store.removeCalendar(calendar, commit: true)
            UserDefaults.standard.removeObject(forKey: calendarIdentifierKey)
        } catch {
            print("CalendarSyncManager: failed to delete calendar: \(error)")
        }
    }

    /// Remove all events in the DueTrack calendar and recreate them from the given bills.
    static func syncAllBills(_ bills: [Bill]) async {
        guard isSyncEnabled else { return }
        guard let calendar = ensureCalendarExists() else { return }

        let calendarStore = eventStore
        let oneYearAhead = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

        // Delete existing events in our range to avoid duplicates.
        let predicate = calendarStore.predicateForEvents(
            withStart: Date.distantPast,
            end: oneYearAhead,
            calendars: [calendar]
        )
        let existing = calendarStore.events(matching: predicate)
        existing.forEach { event in
            do {
                try calendarStore.remove(event, span: .thisEvent, commit: false)
            } catch {
                print("CalendarSyncManager: failed to remove event: \(error)")
            }
        }
        do {
            try calendarStore.commit()
        } catch {
            print("CalendarSyncManager: commit delete failed: \(error)")
        }

        // Add simple one-off events for upcoming occurrences within next year.
        let calendarUtil = Calendar.current

        for bill in bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()

            var next = bill.nextDueDate
            // Only create events up to one year out.
            while next <= oneYearAhead {
                let event = EKEvent(eventStore: calendarStore)
                event.calendar = calendar
                event.title = bill.name
                event.notes = String(format: "%.2f %@", bill.amount, Locale.current.currency?.identifier ?? "")
                event.startDate = next
                event.endDate = calendarUtil.date(byAdding: .hour, value: 1, to: next) ?? next
                event.isAllDay = true

                do {
                    try calendarStore.save(event, span: .thisEvent, commit: false)
                } catch {
                    print("CalendarSyncManager: failed to save event: \(error)")
                }

                // Advance to next occurrence.
                next = DateHelpers.nextOccurrence(
                    from: next,
                    frequency: frequency,
                    customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                    customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
                )

                // Break if we somehow don't advance.
                if next <= startDate { break }
            }
        }

        do {
            try calendarStore.commit()
        } catch {
            print("CalendarSyncManager: commit save failed: \(error)")
        }
    }
}


