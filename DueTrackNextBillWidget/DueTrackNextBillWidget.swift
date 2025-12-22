//
//  DueTrackNextBillWidget.swift
//  DueTrackNextBillWidget
//
//  Created by Frank Gabriel on 12/9/25.
//

import WidgetKit
import SwiftUI
import Foundation

// MARK: - Shared models used by the widget (match WidgetDataManager)

struct NextBillSnapshot: Codable {
    let billId: UUID?
    let name: String
    let amount: Double
    let dueDate: Date
    let isOverdue: Bool
}

enum WidgetShared {
    // MUST match the App Group you configured in Signing & Capabilities
    private static let appGroupId = "group.com.frankg.DueTrack"
    private static let nextBillKey = "nextBillSnapshot"
    private static let thisWeekKey = "thisWeekSnapshot"

    static func loadNextBillSnapshot() -> NextBillSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let data = defaults.data(forKey: nextBillKey)
        else {
            return nil
        }
        return try? JSONDecoder().decode(NextBillSnapshot.self, from: data)
    }
}

struct WeekBillSnapshot: Codable {
    let billId: UUID?
    let name: String
    let amount: Double
    let dueDate: Date
    let isOverdue: Bool
    let category: String
    /// Whether this specific occurrence has been marked paid.
    /// Optional for backward compatibility with older stored snapshots.
    let isPaid: Bool?
}

extension WidgetShared {
    static func loadThisWeekSnapshot() -> [WeekBillSnapshot]? {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let data = defaults.data(forKey: thisWeekKey)
        else {
            return nil
        }
        return try? JSONDecoder().decode([WeekBillSnapshot].self, from: data)
    }
}

// MARK: - Timeline

struct NextBillEntry: TimelineEntry {
    let date: Date
    let snapshot: NextBillSnapshot?
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = NextBillEntry

    func placeholder(in context: Context) -> NextBillEntry {
        NextBillEntry(
            date: Date(),
            snapshot: NextBillSnapshot(
                billId: UUID(),
                name: "Sample Bill",
                amount: 17.00,
                dueDate: Date(),
                isOverdue: false
            )
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent,
                  in context: Context) async -> NextBillEntry {
        NextBillEntry(date: Date(), snapshot: WidgetShared.loadNextBillSnapshot())
    }

    func timeline(for configuration: ConfigurationAppIntent,
                  in context: Context) async -> Timeline<NextBillEntry> {
        let entry = NextBillEntry(date: Date(), snapshot: WidgetShared.loadNextBillSnapshot())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

// MARK: - View

struct DueTrackNextBillWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 6) {
                Text("Next Bill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(s.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(formatAmount(s.amount))
                    .font(.title3).bold()

                Text(formatDate(s.dueDate))
                    .font(.caption)
                    .foregroundColor(s.isOverdue ? .red : .secondary)
            }
            .padding()
        } else {
            VStack {
                Text("Next Bill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("No upcoming bills 🎉")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private func formatAmount(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Widget

struct DueTrackNextBillWidget: Widget {
    let kind: String = "DueTrackNextBillWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in
            DueTrackNextBillWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Bill Due")
        .description("See your next upcoming or overdue bill at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - "This Week" Widget

struct ThisWeekEntry: TimelineEntry {
    let date: Date
    let bills: [WeekBillSnapshot]
}

struct ThisWeekProvider: AppIntentTimelineProvider {
    typealias Entry = ThisWeekEntry
    
    func placeholder(in context: Context) -> ThisWeekEntry {
        ThisWeekEntry(
            date: Date(),
            bills: [
                WeekBillSnapshot(
                    billId: UUID(),
                    name: "Sample 1",
                    amount: 15.99,
                    dueDate: Date(),
                    isOverdue: false,
                    category: "Utilities",
                    isPaid: false
                ),
                WeekBillSnapshot(
                    billId: UUID(),
                    name: "Sample 2",
                    amount: 29.99,
                    dueDate: Date().addingTimeInterval(86400),
                    isOverdue: false,
                    category: "Subscriptions",
                    isPaid: false
                )
            ]
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent,
                  in context: Context) async -> ThisWeekEntry {
        let bills = WidgetShared.loadThisWeekSnapshot() ?? []
        return ThisWeekEntry(date: Date(), bills: bills)
    }
    
    func timeline(for configuration: ConfigurationAppIntent,
                  in context: Context) async -> Timeline<ThisWeekEntry> {
        let bills = WidgetShared.loadThisWeekSnapshot() ?? []
        let entry = ThisWeekEntry(date: Date(), bills: bills)
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        return Timeline(entries: [entry], policy: .after(refresh))
    }
}

struct DueTrackThisWeekWidgetEntryView: View {
    var entry: ThisWeekEntry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        switch family {
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }
    
    // MARK: - Small: Today only
    private var smallLayout: some View {
        let calendar = Calendar.current
        let today = Date()
        let todayBills = entry.bills.filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
        
        return VStack(alignment: .leading, spacing: 6) {
            // Header: weekday + day number
            Text(today.weekdayUppercased)
                .font(.caption)
                .foregroundColor(.red)
            Text(today.dayString)
                .font(.system(size: 32, weight: .bold))
            
            if todayBills.isEmpty {
                Text("No bills due today")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(todayBills.prefix(3), id: \.name) { bill in
                    let isPaid = bill.isPaid ?? false
                    Text(bill.name)
                        .font(.subheadline)
                        .foregroundColor(isPaid ? .secondary : Color.categoryColor(for: bill.category))
                        .strikethrough(isPaid)
                        .lineLimit(1)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Medium: Today & Tomorrow
    private var mediumLayout: some View {
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        let todayBills = entry.bills.filter { calendar.isDate($0.dueDate, inSameDayAs: today) }
        let tomorrowBills = entry.bills.filter { calendar.isDate($0.dueDate, inSameDayAs: tomorrow) }
        
        return HStack(alignment: .top, spacing: 12) {
            dayColumn(
                title: "TODAY",
                date: today,
                bills: todayBills,
                emptyText: "No bills due"
            )
            
            dayColumn(
                title: "TOMORROW",
                date: tomorrow,
                bills: tomorrowBills,
                emptyText: "You're all set"
            )
        }
        .padding()
    }
    
    private func dayColumn(
        title: String,
        date: Date,
        bills: [WeekBillSnapshot],
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(date.dayString)
                .font(.system(size: 24, weight: .bold))
            
            if bills.isEmpty {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                ForEach(bills.prefix(3), id: \.name) { bill in
                    let isPaid = bill.isPaid ?? false
                    Text(bill.name)
                        .font(.subheadline)
                        .foregroundColor(isPaid ? .secondary : Color.categoryColor(for: bill.category))
                        .strikethrough(isPaid)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct DueTrackThisWeekWidget: Widget {
    let kind: String = "DueTrackThisWeekWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: ThisWeekProvider()
        ) { entry in
            DueTrackThisWeekWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Bills This Week")
        .description("See bills due in the next 7 days.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Helpers

private extension Date {
    var weekdayUppercased: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: self).uppercased()
    }
    
    var dayString: String {
        let day = Calendar.current.component(.day, from: self)
        return "\(day)"
    }
}

private extension Color {
    static func categoryColor(for category: String) -> Color {
        switch category {
        case "Utilities": return Color(red: 59/255, green: 130/255, blue: 246/255)    // #3B82F6
        case "Subscriptions": return Color(red: 139/255, green: 92/255, blue: 246/255) // #8B5CF6
        case "Loans": return Color(red: 236/255, green: 72/255, blue: 153/255)        // #EC4899
        case "Insurance": return Color(red: 16/255, green: 185/255, blue: 129/255)    // #10B981
        case "Rent": return Color(red: 249/255, green: 115/255, blue: 22/255)         // #F97316 (Home)
        case "Credit Card": return Color(red: 245/255, green: 158/255, blue: 11/255)  // #F59E0B
        default: return Color(red: 107/255, green: 114/255, blue: 128/255)            // #6B7280
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    DueTrackNextBillWidget()
} timeline: {
    NextBillEntry(
        date: .now,
        snapshot: NextBillSnapshot(
            billId: UUID(),
            name: "Sample Bill",
            amount: 17.00,
            dueDate: .now,
            isOverdue: false
        )
    )
}
