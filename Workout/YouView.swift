import SwiftUI
import UIKit

/// Personal dashboard: today's calories vs. goal, the current streak, and this week.
struct YouView: View {
    @EnvironmentObject var store: Store
    @State private var now = Date()

    private var caloriesToday: Int { store.calories(on: now) }
    private var caloriesWeek: Int { store.caloriesInWeek(containing: now) }
    private var goal: Int { store.profile.effectiveWeeklyGoal }
    private var progress: Double { min(Double(caloriesWeek) / Double(goal), 1) }
    private var streak: Int { Streak.currentStreak(dates: store.completionDates, now: now) }

    private var message: String {
        if caloriesWeek >= goal { return "Weekly goal reached. Great work!" }
        if caloriesWeek > 0 { return "\((goal - caloriesWeek).formatted()) kcal to go this week. Keep it up!" }
        if streak > 0 { return "Keep your streak going!" }
        return "One workout at a time."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        wheelCard
                        streakCard
                        StreakBar(showsMessage: false)
                    }
                    .padding(Theme.spacing)
                }
            }
            .navigationTitle("You")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                now = Date()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                now = Date()
            }
        }
    }

    private var wheelCard: some View {
        Card {
            VStack(spacing: 18) {
                ActivityWheel(progress: progress)
                    .frame(width: 200, height: 200)
                    .padding(.top, 8)
                VStack(spacing: 4) {
                    Text("\(caloriesWeek.formatted()) kcal")
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    Text("this week · goal \(goal.formatted()) kcal")
                        .font(Theme.caption()).foregroundStyle(Theme.secondary)
                    Text("Today: \(caloriesToday.formatted()) kcal")
                        .font(Theme.caption()).foregroundStyle(Theme.secondary)
                        .padding(.top, 2)
                }
                Text(message)
                    .font(Theme.body())
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var streakCard: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(streak > 0 ? Theme.flame : Theme.line)
                VStack(alignment: .leading, spacing: 2) {
                    Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
                        .font(Theme.headline())
                    Text(streak > 0 ? "Days in a row with a saved workout"
                                    : "Save a workout to start a streak")
                        .font(Theme.caption()).foregroundStyle(Theme.secondary)
                }
                Spacer()
            }
        }
    }
}

/// Ring showing progress toward the daily calorie goal, with a flame in the middle.
struct ActivityWheel: View {
    let progress: Double

    private let lineWidth: CGFloat = 18

    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.001))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 1.0, green: 0.78, blue: 0.25),
                            Theme.flame,
                            Color(red: 0.88, green: 0.22, blue: 0.1),
                        ]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(progress, 0.05))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.flame.opacity(progress > 0 ? 0.3 : 0), radius: 8)
                .animation(.easeOut(duration: 0.6), value: progress)
            Image(systemName: "flame.fill")
                .font(.system(size: 54))
                .foregroundStyle(progress > 0 ? Theme.flame : Theme.line)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly calorie goal \(Int(progress * 100)) percent complete")
    }
}
