import Foundation

public struct DateHelpers {
    
    /// Calculate the next due date based on due day and frequency
    public static func calculateNextDueDate(
        dueDay: Int,
        frequency: BillFrequency,
        from date: Date = Date()
    ) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        
        switch frequency {
        case .weekly:
            // Find next occurrence of the weekday
            let weekday = calendar.component(.weekday, from: date)
            var daysToAdd = (dueDay - weekday + 7) % 7
            if daysToAdd == 0 { daysToAdd = 7 }
            return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
            
        case .biWeekly:
            // Every 2 weeks from a base date
            let baseDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: dueDay)) ?? date
            let weeksSinceBase = calendar.dateComponents([.weekOfYear], from: baseDate, to: date).weekOfYear ?? 0
            let nextWeek = ((weeksSinceBase / 2) + 1) * 2
            return calendar.date(byAdding: .weekOfYear, value: nextWeek, to: baseDate) ?? date
            
        case .monthly:
            // Next occurrence of the day in month
            components.day = min(dueDay, calendar.range(of: .day, in: .month, for: date)?.count ?? 31)
            var nextDate = calendar.date(from: components) ?? date
            
            // If the date has passed this month, move to next month
            if nextDate < date {
                components.month = (components.month ?? 1) + 1
                if components.month ?? 1 > 12 {
                    components.month = 1
                    components.year = (components.year ?? 2024) + 1
                }
                // Handle month-end edge cases
                let maxDay = calendar.range(of: .day, in: .month, for: calendar.date(from: components) ?? date)?.count ?? 31
                components.day = min(dueDay, maxDay)
                nextDate = calendar.date(from: components) ?? date
            }
            return nextDate
            
        case .quarterly:
            // Every 3 months
            components.day = min(dueDay, calendar.range(of: .day, in: .month, for: date)?.count ?? 31)
            var nextDate = calendar.date(from: components) ?? date
            
            if nextDate < date {
                components.month = (components.month ?? 1) + 3
                if components.month ?? 1 > 12 {
                    components.month = (components.month ?? 1) % 12
                    components.year = (components.year ?? 2024) + 1
                }
                let maxDay = calendar.range(of: .day, in: .month, for: calendar.date(from: components) ?? date)?.count ?? 31
                components.day = min(dueDay, maxDay)
                nextDate = calendar.date(from: components) ?? date
            }
            return nextDate
            
        case .annual:
            // Once per year
            components.day = min(dueDay, calendar.range(of: .day, in: .month, for: date)?.count ?? 31)
            var nextDate = calendar.date(from: components) ?? date
            
            if nextDate < date {
                components.year = (components.year ?? 2024) + 1
                // Handle leap year for Feb 29
                let maxDay = calendar.range(of: .day, in: .month, for: calendar.date(from: components) ?? date)?.count ?? 31
                components.day = min(dueDay, maxDay)
                nextDate = calendar.date(from: components) ?? date
            }
            return nextDate
            
        case .custom:
            // For custom, assume monthly for now
            return calculateNextDueDate(dueDay: dueDay, frequency: .monthly, from: date)
        }
    }
    
    /// Format date for display
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Get whole days between today and a target date.
    /// Uses start-of-day for both so "tomorrow" is 1 even if it's <24 hours away.
    static func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTarget = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfTarget)
        return components.day ?? 0
    }
    
    /// Check if date is in current month
    static func isInCurrentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    /// Get all occurrences of a recurring bill for a given month.
    /// For `.custom` frequency, provide customInterval/customUnit.
    static func occurrencesForMonth(
        startDate: Date,
        frequency: BillFrequency,
        customInterval: Int? = nil,
        customUnit: CustomRecurrenceUnit? = nil,
        for month: Date
    ) -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        var occurrences: [Date] = []
        
        // If start date is after the month, no occurrences
        if startDate > endOfMonth {
            return []
        }
        
        // Find the first occurrence on or after the start of the month
        var currentDate = nextScheduledDate(
            startDate: startDate,
            frequency: frequency,
            customInterval: customInterval,
            customUnit: customUnit,
            after: startOfMonth
        )
        // If first occurrence is after the month, return empty
        if currentDate > endOfMonth {
            return []
        }
        
        // Generate all occurrences in the month
        while currentDate <= endOfMonth {
            occurrences.append(currentDate)
            currentDate = nextOccurrence(
                from: currentDate,
                frequency: frequency,
                customInterval: customInterval,
                customUnit: customUnit
            )
            // Safety check to prevent infinite loop
            if occurrences.count > 100 {
                break
            }
        }
        
        return occurrences
    }
    
    /// Get the first scheduled occurrence on or after a given date.
    static func nextScheduledDate(
        startDate: Date,
        frequency: BillFrequency,
        customInterval: Int? = nil,
        customUnit: CustomRecurrenceUnit? = nil,
        after date: Date
    ) -> Date {
        var currentDate = startDate
        
        // If the start date is already on or after the reference date, use it
        if currentDate >= date {
            return currentDate
        }
        
        // Step forward by frequency until we land on or after the reference date
        var safetyCounter = 0
        while currentDate < date && safetyCounter < 1000 {
            let next = nextOccurrence(
                from: currentDate,
                frequency: frequency,
                customInterval: customInterval,
                customUnit: customUnit
            )
            // Safety: break if next didn't advance
            if next <= currentDate {
                break
            }
            currentDate = next
            safetyCounter += 1
        }
        
        return currentDate
    }
    
    /// Get the next occurrence after a given date
    static func nextOccurrence(
        from date: Date,
        frequency: BillFrequency,
        customInterval: Int? = nil,
        customUnit: CustomRecurrenceUnit? = nil
    ) -> Date {
        let calendar = Calendar.current
        
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biWeekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date) ?? date
        case .annual:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case .custom:
            guard let interval = customInterval, let unit = customUnit else {
                // Fallback to monthly if custom data missing
                return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            }
            switch unit {
            case .days:
                return calendar.date(byAdding: .day, value: interval, to: date) ?? date
            case .weeks:
                return calendar.date(byAdding: .day, value: 7 * interval, to: date) ?? date
            case .months:
                return calendar.date(byAdding: .month, value: interval, to: date) ?? date
            case .years:
                return calendar.date(byAdding: .year, value: interval, to: date) ?? date
            }
        }
    }
    
    /// Determine if a given bill occurrence is considered paid, based on its frequency and payments.
    /// A payment counts for an occurrence if it is marked paid and its date falls between the
    /// occurrence date (inclusive) and the next occurrence (inclusive).
    static func isOccurrencePaid(
        occurrenceDate: Date,
        frequency: BillFrequency,
        payments: [Payment],
        customInterval: Int? = nil,
        customUnit: CustomRecurrenceUnit? = nil
    ) -> Bool {
        let next = nextOccurrence(
            from: occurrenceDate,
            frequency: frequency,
            customInterval: customInterval,
            customUnit: customUnit
        )
        return payments.contains { payment in
            payment.isPaid &&
            payment.datePaid >= occurrenceDate &&
            payment.datePaid <= next
        }
    }
}

