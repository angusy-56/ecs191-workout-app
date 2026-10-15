import SwiftUI
import UIKit

/// Weekly activity logic: a week runs Monday to Sunday in the user's local calendar.
enum Streak {
    static var calendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    /// The seven days (Monday first) of the week containing `date`.
    static func weekDays(containing date: Date) -> [Date] {
        let cal = calendar
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? cal.startOfDay(for: date)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// Consecutive days with activity, ending today (or yesterday if today has none yet).
    static func currentStreak(dates: [Date], now: Date = Date()) -> Int {
        let cal = calendar
        let days = Set(dates.map { cal.startOfDay(for: $0) })
        var day = cal.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }
}

/// Compact Monday–Sunday bar. A day lights up once a strength or cardio session is saved on it.
struct StreakBar: View {
    @EnvironmentObject var store: Store
    @State private var now = Date()
    var showsMessage = true

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    private var days: [Date] { Streak.weekDays(containing: now) }

    private func isDone(_ day: Date) -> Bool {
        store.completionDates.contains { Streak.isSameDay($0, day) }
    }

    private var doneCount: Int { days.filter(isDone).count }
    private var todayDone: Bool { days.contains { Streak.isSameDay($0, now) && isDone($0) } }

    private var message: String {
        if todayDone { return "Nice work today. One workout at a time." }
        if doneCount > 0 { return "Keep your streak going!" }
        return "One workout at a time."
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                        dayView(letter: Self.letters[i], day: day)
                    }
                }
                if showsMessage {
                    Text(message)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            now = Date()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            now = Date()
        }
    }

    private func dayView(letter: String, day: Date) -> some View {
        let today = Streak.isSameDay(day, now)
        let done = isDone(day)
        return VStack(spacing: 8) {
            Text(letter)
                .font(Theme.caption())
                .foregroundStyle(today ? Theme.text : Theme.secondary)
                .fontWeight(today ? .bold : .medium)
            ZStack {
                Circle()
                    .fill(done ? Theme.flame.opacity(0.14) : Color.clear)
                Circle()
                    .stroke(today ? Theme.text : Theme.line, lineWidth: today ? 1.5 : 1)
                if done {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.flame)
                }
            }
            .frame(width: 34, height: 34)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide))), \(done ? "workout completed" : "no workout")\(today ? ", today" : "")")
    }
}
