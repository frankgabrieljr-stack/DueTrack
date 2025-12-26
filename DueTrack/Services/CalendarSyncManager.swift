//
//  CalendarSyncManager.swift
//  DueTrack
//
//  Created by Frank Gabriel on 12/25/25.
//
import Foundation
import EventKit
import CoreData

enum CalendarSyncManager {
    private static let eventStore = EKEventStore()
    private static let calendarIdentifierKey = "DueTrackCalendarIdentifier"

    static var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "calendarSyncEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "calendarSyncEnabled") }
    }

    static func requestAccessIfNeeded() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .authorized:
            return ensureCalendarExists() != nil
        case .notDetermined:
            do {
                let granted = try await eventStore.requestAccess(to: .event)
                if granted { return ensureCalendarExists() != nil }
                return false
            } catch {
                print("CalendarSyncManager: requestAccess failed: \(error)")
                return false
            }
        default:
            return false
        }
    }

    @discardableResult
    private static func ensureCalendarExists() -> EKCalendar? {
        // Reuse previously created calendar if possible.
        if let id = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let existing = eventStore.calendar(withIdentifier: id) {
            return existing
        }

        // Find a writable calendar and use its source (iCloud/local/etc.).
        let writableCalendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }

        guard let writableSource = writableCalendars.first?.source ??
                eventStore.defaultCalendarForNewEvents?.source else {
            print("CalendarSyncManager: no writable calendar source available.")
            return nil
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = "DueTrack Bills"
        calendar.source = writableSource

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
            return calendar
        } catch {
            print("CalendarSyncManager: failed to save calendar: \(error)")
            return nil
        }
    }

    static func syncAllBills(_ bills: [Bill]) async {
        guard isSyncEnabled else { return }
        guard let calendar = ensureCalendarExists() else { return }

        let store = eventStore
        let oneYearAhead = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

        let predicate = store.predicateForEvents(
            withStart: Date.distantPast,
            end: oneYearAhead,
            calendars: [calendar]
        )
        let existing = store.events(matching: predicate)
        existing.forEach {
            do { try store.remove($0, span: .thisEvent, commit: false) }
            catch { print("CalendarSyncManager: remove event failed: \(error)") }
        }
        do { try store.commit() } catch { print("CalendarSyncManager: commit delete failed: \(error)") }

        for bill in bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            var next = bill.nextDueDate
            let cal = Calendar.current

            while next <= oneYearAhead {
                let event = EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = bill.name
                event.notes = String(format: "%.2f %@", bill.amount, Locale.current.currency?.identifier ?? "")
                event.startDate = next
                event.endDate = cal.date(byAdding: .hour, value: 1, to: next) ?? next
                event.isAllDay = true

                do { try store.save(event, span: .thisEvent, commit: false) }
                catch { print("CalendarSyncManager: save event failed: \(error)") }

                next = DateHelpers.nextOccurrence(
                    from: next,
                    frequency: frequency,
                    customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                    customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
                )
                if next <= startDate { break }
            }
        }

        do { try store.commit() } catch { print("CalendarSyncManager: commit save failed: \(error)") }
    }
}
