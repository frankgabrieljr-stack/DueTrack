import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var selectedTrendRange: TrendRange = .months6
    @State private var selectedMonth = Date()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Monthly Spending
                    MonthlySpendingCard(selectedMonth: selectedMonth)
                    
                    // Payment Performance Trends
                    PaymentTrendCard(selectedRange: $selectedTrendRange, selectedMonth: $selectedMonth)

                    // Category Breakdown
                    CategoryBreakdownCard(selectedMonth: selectedMonth)
                    
                    // Bills needing attention
                    UpcomingBillsCard()
                }
                .padding()
            }
            .navigationTitle("Insights")
        }
    }
}

enum TrendRange: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case months3 = "Past 3 Months"
    case months6 = "Past 6 Months"
    case months12 = "Past 12 Months"
    case allHistory = "All History"
    
    var id: String { rawValue }

    var isMonthly: Bool {
        switch self {
        case .months3, .months6, .months12, .allHistory:
            return true
        case .daily, .weekly:
            return false
        }
    }
}

private struct TrendPoint: Identifiable {
    let id: String
    let label: String
    let month: Date?
    let total: Int
    let onTime: Int
    let late: Int
}

struct PaymentTrendCard: View {
    @Binding var selectedRange: TrendRange
    @Binding var selectedMonth: Date
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel

    private var points: [TrendPoint] {
        switch selectedRange {
        case .daily:
            return dailyPoints()
        case .weekly:
            return weeklyPoints()
        case .months3:
            return monthlyPoints(limit: 3)
        case .months6:
            return monthlyPoints(limit: 6)
        case .months12:
            return monthlyPoints(limit: 12)
        case .allHistory:
            return monthlyPoints(limit: nil)
        }
    }

    private var summary: (total: Int, onTime: Int, late: Int, unpaid: Int) {
        if isMonthlyRange {
            let stats = statsForMonth(selectedMonth)
            let unpaid = max(0, stats.total - stats.onTime - stats.late)
            return (stats.total, stats.onTime, stats.late, unpaid)
        }

        let totals = points.reduce(into: (0, 0, 0)) { partial, point in
            partial.0 += point.total
            partial.1 += point.onTime
            partial.2 += point.late
        }
        let unpaid = max(0, totals.0 - totals.1 - totals.2)
        return (totals.0, totals.1, totals.2, unpaid)
    }

    private var isMonthlyRange: Bool {
        selectedRange.isMonthly
    }

    private var selectedMonthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Payment Trend")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.adaptiveText)
                
                Spacer()
                
                Menu {
                    ForEach(TrendRange.allCases) { range in
                        Button(range.rawValue) {
                            selectedRange = range
                            if range.isMonthly {
                                selectedMonth = Date()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedRange.rawValue)
                            .font(.caption)
                            .foregroundColor(.adaptiveSecondaryText)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                }
            }

            TrendLegendView()

            if points.allSatisfy({ $0.total == 0 }) {
                Text("No bill activity in this range")
                    .font(.subheadline)
                    .foregroundColor(.adaptiveSecondaryText)
            } else {
                TrendBarChart(
                    points: points,
                    selectedMonth: selectedMonth,
                    onSelectMonth: { selectedMonth = $0 }
                )
            }

            if isMonthlyRange {
                Text("Selected: \(selectedMonthTitle)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.adaptiveSecondaryText)
            }

            HStack(spacing: 12) {
                StatPill(title: "Total", value: "\(summary.total)", color: .primaryBlue)
                StatPill(title: "On Time", value: "\(summary.onTime)", color: .accentGreen)
                StatPill(title: "Late", value: "\(summary.late)", color: .overdueRed)
                StatPill(title: "Unpaid", value: "\(summary.unpaid)", color: .adaptiveSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }

    private func monthRange(for date: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        return startOfMonth...endOfMonth
    }

    private func weekRanges(in month: Date) -> [ClosedRange<Date>] {
        let calendar = Calendar.current
        let range = monthRange(for: month)
        let start = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)

        var weeks: [ClosedRange<Date>] = []
        var currentStart = start

        while currentStart <= end {
            let nextStart = calendar.date(byAdding: .day, value: 7, to: currentStart)!
            let currentEnd = min(calendar.date(byAdding: .day, value: -1, to: nextStart)!, end)
            weeks.append(currentStart...currentEnd)
            currentStart = nextStart
        }

        return weeks
    }

    private func dailyPoints() -> [TrendPoint] {
        let calendar = Calendar.current
        let month = Date()
        let range = monthRange(for: month)
        let start = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
        
        var days: [Date] = []
        var current = start
        while current <= end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return days.map { day in
            let stats = statsForOccurrences(in: day...day, month: month)
            return TrendPoint(
                id: "day-\(day.timeIntervalSince1970)",
                label: "\(calendar.component(.day, from: day))",
                month: nil,
                total: stats.total,
                onTime: stats.onTime,
                late: stats.late
            )
        }
    }

    private func weeklyPoints() -> [TrendPoint] {
        let month = Date()
        let weeks = weekRanges(in: month)
        return weeks.enumerated().map { index, range in
            let stats = statsForOccurrences(in: range, month: month)
            return TrendPoint(
                id: "week-\(range.lowerBound.timeIntervalSince1970)",
                label: "W\(index + 1)",
                month: nil,
                total: stats.total,
                onTime: stats.onTime,
                late: stats.late
            )
        }
    }

    private func monthlyPoints(limit: Int?) -> [TrendPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        guard let earliest = billViewModel.bills
            .compactMap({ $0.createdDate })
            .min() else {
            return []
        }

        let startMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest))!
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!

        var months: [Date] = []
        var cursor = startMonth
        while cursor <= currentMonth {
            months.append(cursor)
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor)!
        }

        if let limit = limit, months.count > limit {
            months = Array(months.suffix(limit))
        }

        return months.map { month in
            let stats = statsForMonth(month)
            return TrendPoint(
                id: "month-\(month.timeIntervalSince1970)",
                label: formatter.string(from: month),
                month: month,
                total: stats.total,
                onTime: stats.onTime,
                late: stats.late
            )
        }
    }

    private func statsForOccurrences(in range: ClosedRange<Date>, month: Date) -> (total: Int, onTime: Int, late: Int) {
        let calendar = Calendar.current
        var total = 0
        var onTime = 0
        var late = 0

        for bill in billViewModel.bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )

            let relevantOccurrences = occurrences.filter { range.contains($0) }
            for occurrence in relevantOccurrences {
                total += 1
                if let paymentDate = matchingPayment(for: bill, occurrenceDate: occurrence)?.datePaid {
                    let dueEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: occurrence))!
                    if paymentDate < dueEnd {
                        onTime += 1
                    } else {
                        late += 1
                    }
                }
            }
        }

        return (total, onTime, late)
    }

    private func statsForMonth(_ month: Date) -> (total: Int, onTime: Int, late: Int) {
        let calendar = Calendar.current
        var total = 0
        var onTime = 0
        var late = 0

        for bill in billViewModel.bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )

            for occurrence in occurrences {
                total += 1
                if let paymentDate = matchingPayment(for: bill, occurrenceDate: occurrence)?.datePaid {
                    let dueEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: occurrence))!
                    if paymentDate < dueEnd {
                        onTime += 1
                    } else {
                        late += 1
                    }
                }
            }
        }

        return (total, onTime, late)
    }

    private func matchingPayment(for bill: Bill, occurrenceDate: Date) -> Payment? {
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        let next = DateHelpers.nextOccurrence(
            from: occurrenceDate,
            frequency: frequency,
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )

        let payments = paymentViewModel.paymentHistory(for: bill)
        let calendar = Calendar.current

        if let payment = payments
            .filter({ $0.dueDate != nil && calendar.isDate($0.effectiveDueDate, inSameDayAs: occurrenceDate) })
            .sorted(by: { $0.datePaid < $1.datePaid })
            .first
        {
            return payment
        }

        return payments
            .filter { $0.dueDate == nil && $0.datePaid >= occurrenceDate && $0.datePaid <= next }
            .sorted(by: { $0.datePaid < $1.datePaid })
            .first
    }
}

private struct TrendLegendView: View {
    var body: some View {
        HStack(spacing: 12) {
            LegendDot(color: .primaryBlue, label: "Total")
            LegendDot(color: .accentGreen, label: "On Time")
            LegendDot(color: .overdueRed, label: "Late")
        }
        .font(.caption)
        .foregroundColor(.adaptiveSecondaryText)
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private struct TrendBarChart: View {
    let points: [TrendPoint]
    let selectedMonth: Date
    let onSelectMonth: (Date) -> Void

    private var maxValue: CGFloat {
        CGFloat(points.map { $0.total }.max() ?? 1)
    }

    private func isSelected(_ point: TrendPoint) -> Bool {
        guard let month = point.month else { return false }
        return Calendar.current.isDate(month, equalTo: selectedMonth, toGranularity: .month)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(points) { point in
                let selected = isSelected(point)
                VStack(spacing: 6) {
                    HStack(alignment: .bottom, spacing: 4) {
                        TrendBar(value: point.total, maxValue: maxValue, color: .primaryBlue)
                        TrendBar(value: point.onTime, maxValue: maxValue, color: .accentGreen)
                        TrendBar(value: point.late, maxValue: maxValue, color: .overdueRed)
                    }
                    Text(point.label)
                        .font(.caption2)
                        .fontWeight(selected ? .semibold : .regular)
                        .foregroundColor(selected ? .primaryBlue : .adaptiveSecondaryText)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
                .background(selected ? Color.primaryBlue.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onTapGesture {
                    if let month = point.month {
                        onSelectMonth(month)
                    }
                }
            }
        }
    }
}

private struct TrendBar: View {
    let value: Int
    let maxValue: CGFloat
    let color: Color

    var body: some View {
        let height = maxValue == 0 ? 0 : (CGFloat(value) / maxValue) * 80
        RoundedRectangle(cornerRadius: 4)
            .fill(color)
            .frame(width: 10, height: max(2, height))
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.cardBackground)
        .cornerRadius(8)
    }
}

struct MonthlySpendingCard: View {
    @EnvironmentObject var billViewModel: BillViewModel
    let selectedMonth: Date

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Spending")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)
            
            Text(billViewModel.totalMonthlyOutflow(for: selectedMonth).currencyString())
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.primaryBlue)
            
            Text("Total recurring bills in \(monthTitle)")
                .font(.subheadline)
                .foregroundColor(.adaptiveSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

struct CategoryBreakdownCard: View {
    @EnvironmentObject var billViewModel: BillViewModel
    let selectedMonth: Date

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }
    
    private var categoryTotals: [(category: BillCategory, total: Double)] {
        var totals: [BillCategory: Double] = [:]

        for bill in billViewModel.bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: bill.createdDate ?? Date(),
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: selectedMonth
            )

            guard !occurrences.isEmpty else { continue }

            let category = BillCategory(rawValue: bill.category) ?? .other
            totals[category, default: 0] += bill.amount * Double(occurrences.count)
        }

        return totals.map { (category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spending by Category")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.adaptiveText)

                Text(monthTitle)
                    .font(.caption)
                    .foregroundColor(.adaptiveSecondaryText)
            }
            
            if categoryTotals.isEmpty {
                Text("No bills yet")
                    .font(.subheadline)
                    .foregroundColor(.adaptiveSecondaryText)
                    .padding(.vertical, 8)
            } else {
                ForEach(categoryTotals, id: \.category) { item in
                    NavigationLink(destination: CategoryBillsDetailView(category: item.category, selectedMonth: selectedMonth)) {
                        HStack(spacing: 12) {
                            Image(systemName: item.category.icon)
                                .foregroundColor(.primaryBlue)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                                .background(Color.primaryBlue.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(item.category.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.adaptiveText)
                            
                            Spacer()
                            
                            Text(item.total.currencyString())
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.adaptiveText)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

struct CategoryBillsDetailView: View {
    let category: BillCategory
    let selectedMonth: Date
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    private var billsInCategory: [Bill] {
        billViewModel.bills
            .filter { $0.category == category.rawValue }
            .filter { billHasOccurrenceInSelectedMonth($0) }
            .sorted { $0.nextDueDate < $1.nextDueDate }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    private func billHasOccurrenceInSelectedMonth(_ bill: Bill) -> Bool {
        let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return !DateHelpers.occurrencesForMonth(
            startDate: bill.createdDate ?? Date(),
            frequency: frequency,
            customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
            for: selectedMonth
        ).isEmpty
    }
    
    var body: some View {
        List {
            Text(monthTitle)
                .font(.subheadline)
                .foregroundColor(.adaptiveSecondaryText)
                .listRowSeparator(.hidden)

            if billsInCategory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.adaptiveSecondaryText.opacity(0.6))
                    Text("No bills in this category")
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                ForEach(billsInCategory, id: \.id) { bill in
                    NavigationLink(destination: BillDetailView(bill: bill)) {
                        BillRowView(bill: bill)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .navigationTitle(category.displayName)
    }
}

struct UpcomingBillsCard: View {
    @EnvironmentObject var billViewModel: BillViewModel
    
    private var upcomingBills: [Bill] {
        billViewModel.upcomingBills().prefix(5).map { $0 }
    }

    private func dateLabel(for bill: Bill) -> String {
        if bill.paymentStatus == .overdue {
            return "Overdue since \(DateHelpers.formatDate(bill.nextDueDate))"
        }

        return "Due \(DateHelpers.formatDate(bill.nextDueDate))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bills Needing Attention")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)
            
            if upcomingBills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentGreen.opacity(0.5))
                    Text("All caught up!")
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                    Text("No overdue or upcoming bills")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(upcomingBills, id: \.id) { bill in
                    HStack(spacing: 12) {
                        // Status indicator
                        Circle()
                            .fill(Color(hex: bill.paymentStatus.color))
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bill.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.adaptiveText)
                            Text(dateLabel(for: bill))
                                .font(.caption)
                                .foregroundColor(.adaptiveSecondaryText)
                        }
                        
                        Spacer()
                        
                        Text(bill.amount.currencyString())
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.adaptiveText)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .cardStyle()
    }
}

