import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var billViewModel: BillViewModel
    @Binding var selectedMonth: Date // Bind to parent's selectedMonth
    @State private var selectedDate = Date()
    
    init(selectedMonth: Binding<Date>) {
        _selectedMonth = selectedMonth
        // Initialize with today's date, not selectedMonth
        _selectedDate = State(initialValue: Date())
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Month Navigation
            MonthNavigationView(selectedDate: $selectedDate)
                .onChange(of: selectedDate) { newDate in
                    // Update parent's selectedMonth when calendar month changes
                    let calendar = Calendar.current
                    let month = calendar.date(from: calendar.dateComponents([.year, .month], from: newDate))!
                    selectedMonth = month
                }
            
            // Calendar Grid
            CalendarGridView(selectedDate: $selectedDate, bills: billViewModel.bills)
            
            // Category legend for color-coded dots
            CategoryLegendView()
            
            // Bills for Selected Date
            BillsForDateView(date: selectedDate)
        }
        .onAppear {
            let calendar = Calendar.current
            let today = Date()
            let todayMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
            let selectedMonthValue = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
            
            // If viewing current month, select today's date
            if calendar.isDate(todayMonth, inSameDayAs: selectedMonthValue) {
                selectedDate = today
            } else {
                // Otherwise, select the first day of the selected month
                selectedDate = selectedMonthValue
            }
            
            // Update parent's selectedMonth to match
            selectedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        }
    }
}

struct MonthNavigationView: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.primaryBlue)
            }
            
            Spacer()
            
            Text(monthYearString)
                .font(.headline)
            
            Spacer()
            
            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.primaryBlue)
            }
        }
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private func changeMonth(_ direction: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: direction, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let bills: [Bill]
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.adaptiveSecondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar days
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(calendarDays, id: \.self) { date in
                    let billsForThisDate = billsForDate(date)
                    CalendarDayView(
                        date: date,
                        isSelected: date.isSameDay(as: selectedDate),
                        bills: billsForThisDate,
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month),
                        isFullyPaid: areAllOccurrencesPaid(on: date, billsForDay: billsForThisDate),
                        hasBills: !billsForThisDate.isEmpty,
                        hasOverdue: hasOverdue(on: date, billsForDay: billsForThisDate)
                    )
                    .onTapGesture {
                        selectedDate = date
                    }
                }
            }
        }
    }
    
    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedDate)!.count
        
        var days: [Date] = []
        
        // Previous month days - fill in days before the 1st to align with weekday headers
        if firstWeekday > 0 {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: selectedDate)!
            let daysInPrevMonth = calendar.range(of: .day, in: .month, for: prevMonth)!.count
            
            // We need 'firstWeekday' days from the previous month
            // Start from the day that will make the grid align correctly
            let startDay = daysInPrevMonth - firstWeekday + 1
            
            for day in startDay...daysInPrevMonth {
                var components = calendar.dateComponents([.year, .month], from: prevMonth)
                components.day = day
                if let date = calendar.date(from: components) {
                    days.append(date)
                }
            }
        }
        
        // Current month days
        for day in 1...daysInMonth {
            var components = calendar.dateComponents([.year, .month], from: startOfMonth)
            components.day = day
            if let date = calendar.date(from: components) {
                days.append(date)
            }
        }
        
        // Next month days to fill grid (always show 6 weeks = 42 days total)
        let remaining = 42 - days.count
        if remaining > 0 {
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            for day in 1...remaining {
                var components = calendar.dateComponents([.year, .month], from: nextMonth)
                components.day = day
                if let date = calendar.date(from: components) {
                    days.append(date)
                }
            }
        }
        
        return days
    }
    
    private func billsForDate(_ date: Date) -> [Bill] {
        let calendar = Calendar.current
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        var billsForDate: [Bill] = []
        
        for bill in bills {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )
            
            // Check if any occurrence matches this date
            if occurrences.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
                billsForDate.append(bill)
            }
        }
        
        return billsForDate
    }
    
    /// Returns true if every bill occurrence on this date has a matching payment.
    private func areAllOccurrencesPaid(on date: Date, billsForDay: [Bill]) -> Bool {
        guard !billsForDay.isEmpty else { return false }
        
        let calendar = Calendar.current
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        
        for bill in billsForDay {
            let frequency = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: frequency,
                customInterval: frequency == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: frequency == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )
            
            let matchingOccurrences = occurrences.filter { calendar.isDate($0, inSameDayAs: date) }
            guard !matchingOccurrences.isEmpty else { continue }
            
            for occurrenceDate in matchingOccurrences {
                let isPaid = DateHelpers.isOccurrencePaid(
                    occurrenceDate: occurrenceDate,
                    frequency: frequency,
                    payments: paymentViewModel.paymentHistory(for: bill)
                )
                
                if !isPaid {
                    return false
                }
            }
        }
        
        return true
    }
    
    /// Returns true if there is at least one unpaid occurrence on this date in the past (overdue).
    private func hasOverdue(on date: Date, billsForDay: [Bill]) -> Bool {
        let calendar = Calendar.current
        let today = Date()
        guard date < today else { return false }
        
        let month = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        
        for bill in billsForDay {
            let freq = BillFrequency(rawValue: bill.frequency) ?? .monthly
            let startDate = bill.createdDate ?? Date()
            let occurrences = DateHelpers.occurrencesForMonth(
                startDate: startDate,
                frequency: freq,
                customInterval: freq == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
                customUnit: freq == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil,
                for: month
            )
            
            let matchingOccurrences = occurrences.filter { calendar.isDate($0, inSameDayAs: date) }
            for occurrenceDate in matchingOccurrences {
                let isPaid = DateHelpers.isOccurrencePaid(
                    occurrenceDate: occurrenceDate,
                    frequency: freq,
                    payments: paymentViewModel.paymentHistory(for: bill)
                )
                if !isPaid {
                    return true
                }
            }
        }
        
        return false
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let bills: [Bill]
    let isCurrentMonth: Bool
    let isFullyPaid: Bool
    let hasBills: Bool
    let hasOverdue: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                .foregroundColor(
                    isCurrentMonth
                    ? (isSelected
                       ? .white
                       : (hasOverdue ? .overdueRed : (isFullyPaid && hasBills ? .accentGreen : .adaptiveText)))
                    : .adaptiveSecondaryText
                )
                .strikethrough(isFullyPaid && hasBills && !isSelected, color: .accentGreen)
            
            // Bill indicators
            HStack(spacing: 2) {
                ForEach(Array(bills.prefix(3)), id: \.id) { bill in
                    let colorHex = BillCategory(rawValue: bill.category)?.colorHex ?? "#6B7280"
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .frame(width: 44, height: 60)
        .background(
            isSelected
            ? Color.primaryBlue
            : (hasOverdue
               ? Color.overdueRed.opacity(0.12)
               : (isFullyPaid && hasBills ? Color.accentGreen.opacity(0.15) : Color.clear))
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasOverdue && !isSelected ? Color.overdueRed : Color.clear, lineWidth: 2)
        )
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
}

struct CategoryLegendView: View {
    private let categories = BillCategory.allCases
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: category.colorHex))
                            .frame(width: 6, height: 6)
                        Text(category.displayName)
                            .font(.caption2)
                            .foregroundColor(.adaptiveSecondaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cardBackground)
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct BillsForDateView: View {
    let date: Date
    @EnvironmentObject var billViewModel: BillViewModel
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    
    private var occurrencesForDate: [(bill: Bill, occurrenceDate: Date)] {
        billViewModel.billOccurrences(for: date)
    }
    
    private func isBillPaid(on occurrenceDate: Date, for bill: Bill) -> Bool {
        let freq = BillFrequency(rawValue: bill.frequency) ?? .monthly
        return DateHelpers.isOccurrencePaid(
            occurrenceDate: occurrenceDate,
            frequency: freq,
            payments: paymentViewModel.paymentHistory(for: bill),
            customInterval: freq == .custom && bill.customInterval > 0 ? Int(bill.customInterval) : nil,
            customUnit: freq == .custom ? CustomRecurrenceUnit(rawValue: bill.customUnit ?? "") : nil
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bills for \(DateHelpers.formatDate(date))")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.adaptiveText)
                .padding(.horizontal)
            
            if occurrencesForDate.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 30))
                        .foregroundColor(.accentGreen.opacity(0.5))
                    Text("No bills due on this date")
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(occurrencesForDate, id: \.occurrenceDate) { item in
                    let paid = isBillPaid(on: item.occurrenceDate, for: item.bill)
                    NavigationLink(destination: BillDetailView(bill: item.bill)) {
                        BillOccurrenceRowView(
                            bill: item.bill,
                            occurrenceDate: item.occurrenceDate,
                            isPaidForOccurrence: paid
                        )
                    }
                }
            }
        }
    }
}

struct BillOccurrenceRowView: View {
    let bill: Bill
    let occurrenceDate: Date
    let isPaidForOccurrence: Bool
    @EnvironmentObject var paymentViewModel: PaymentViewModel
    @State private var isSaving = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Category Icon
            Image(systemName: BillCategory(rawValue: bill.category)?.icon ?? "ellipsis.circle.fill")
                .foregroundColor(.primaryBlue)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(bill.name)
                        .font(.headline)
                        .foregroundColor(.adaptiveText)
                        .strikethrough(isPaidForOccurrence)
                    
                    if isPaidForOccurrence {
                        Text("Paid")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentGreen)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 4) {
                    Text(bill.amount.currencyString())
                        .font(.subheadline)
                        .foregroundColor(.adaptiveSecondaryText)
                        .strikethrough(isPaidForOccurrence)
                    
                    Text("•")
                        .foregroundColor(.adaptiveSecondaryText)
                    
                    Text("Due \(DateHelpers.formatDate(occurrenceDate))")
                        .font(.caption)
                        .foregroundColor(.adaptiveSecondaryText)
                }
            }
            
            Spacer()
            
            if !isPaidForOccurrence {
                Button(action: markOccurrenceAsPaid) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentGreen)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSaving)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func markOccurrenceAsPaid() {
        guard !isSaving else { return }
        isSaving = true
        let success = paymentViewModel.markBillAsPaid(bill, on: occurrenceDate)
        
        // Small async bounce to ensure Core Data updates propagate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isSaving = false
            if !success {
                print("Failed to mark occurrence as paid")
            }
        }
    }
}

