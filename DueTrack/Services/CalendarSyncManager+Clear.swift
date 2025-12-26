//
//  CalendarSyncManager+Clear.swift
//  DueTrack
//
//  Created by Frank Gabriel on 12/25/25.
//

import Foundation
import EventKit

/// Separate extension so we can safely clear the DueTrack calendar when the
/// user turns calendar sync OFF, without touching the main sync logic.
extension CalendarSyncManager {
    /// Remove all events from the DueTrack calendar and delete the calendar itself.
    static func clearCalendar() {
        let calendarIdentifierKey = "DueTrackCalendarIdentifier"
        let store = EKEventStore()

        // Look up the existing DueTrack calendar by its stored identifier
        guard let id = UserDefaults.standard.string(forKey: calendarIdentifierKey),
              let calendar = store.calendar(withIdentifier: id) else {
            return
        }

        // Remove all events in that calendar
        let predicate = store.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]
        )

        let events = store.events(matching: predicate)
        for event in events {
            do {
                try store.remove(event, span: .thisEvent, commit: false)
            } catch {
                print("CalendarSyncManager.clearCalendar: failed to remove event: \(error)")
            }
        }

        // Delete the calendar itself and clear the stored identifier
        do {
            try store.removeCalendar(calendar, commit: true)
            UserDefaults.standard.removeObject(forKey: calendarIdentifierKey)
        } catch {
            print("CalendarSyncManager.clearCalendar: failed to delete calendar: \(error)")
        }
    }
}
