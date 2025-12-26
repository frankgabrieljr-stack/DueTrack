//
//  CalendarSyncManager+Clear.swift
//  DueTrack
//
//  Created by Frank Gabriel on 12/25/25.
//

import Foundation
import EventKit

/// Separate extension so we can safely clear the DueTrack calendar when the
/// user turns calendar sync OFF, without modifying the main sync logic.
extension CalendarSyncManager {
    /// Remove all events from the DueTrack calendar and delete the calendar itself.
    static func clearCalendar() {
        let calendarIdentifierKey = "DueTrackCalendarIdentifier"
        let store = EKEventStore()

        guard let id = UserDefaults.standard.string(forKey: calendarIdentifierKey),
              let calendar = store.calendar(withIdentifier: id) else {
            return
        }

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
                print("CalendarSyncManager.clearCalendar: failed to remove event: \(error)")
            }
        }

        do {
            try store.removeCalendar(calendar, commit: true)
            UserDefaults.standard.removeObject(forKey: calendarIdentifierKey)
        } catch {
            print("CalendarSyncManager.clearCalendar: failed to delete calendar: \(error)")
        }
    }
}


