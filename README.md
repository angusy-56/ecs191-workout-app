# Workout

A small, clean iOS workout tracker (Swift + SwiftUI). No accounts, no subscriptions, no network —
everything is stored on the device.

## Run it

Requires Xcode 16+ and an iOS 17+ simulator or device.

1. Open `Workout.xcodeproj` in Xcode.
2. Pick an iPhone simulator and press **Run** (⌘R).
   To run on a physical iPhone, select the *Workout* target → *Signing & Capabilities* and choose your team.

Or from the command line:

```bash
xcodebuild -project Workout.xcodeproj -scheme Workout \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## Use it

- **Workouts** – tap **+** to create a routine: name it, add exercises from the library
  (or type a new name to create a custom exercise), and set the number of sets. Edit or delete
  routines from the **⋯** menu.
- **Start** a routine to log it. Weight and reps are prefilled from your last session of each
  exercise. Tap the circle to complete a set — the rest timer starts automatically
  (−15 / +15 / Skip). The clock at the top is the total workout time. Long-press a set to remove it.
- **Finish** saves only the completed sets to **History**.
- **History** – review past sessions (time, sets, total volume, estimated calories); swipe to delete.
- **You** – this week's calories as a ring toward your weekly goal, your current streak and this week's
  Monday–Sunday flames. The gear (top right) opens **Settings**.
- **Settings** – units (metric/imperial), age, height, weight (for the calorie estimate), and
  default rest time.

## Cardio and the weekly streak

- **Cardio** (card on the Workouts screen): pick one of 12 activities (running, walking, incline
  walk, cycling, StairMaster, hiking, swimming, rowing, basketball, pickleball, soccer, tennis) and an
  effort level (Easy to Very Hard), then either start a timer and finish it, or enter the details manually. Distance,
  pace/speed, incline and estimated calories are shown where they apply. No GPS or HealthKit.
- **Weekly streak bar** (top of Workouts): Monday to Sunday of the current week. A day shows a flame
  once a strength workout or cardio session is *saved* on it. Starting or opening something does not count.
  Today is outlined, and the week rolls over automatically.
- **Starter routines**: tap **+** and pick Push, Pull, Legs, Upper Body, Lower Body or Full Body.
  You get an editable copy and save your own version.
- **Exercise library** is grouped by muscle group with equipment labels; custom exercises still work.

## Calories

Cardio calories are an estimate: MET (by activity and effort) x your weight x hours.

Strength: a rough estimate: resting energy from the Mifflin-St Jeor formula (sex-neutral) × 5 MET (weight
training) × workout duration. It is only a ballpark figure.

## Code layout (`Workout/`)

| File | Purpose |
|---|---|
| `Models.swift` | Data types, calorie estimate, built-in exercise list |
| `Store.swift` | Saved data, persisted as JSON in the app's Documents folder |
| `ActiveWorkout.swift` | State and timers for the workout in progress |
| `Theme.swift` | Fonts, colors, spacing, shared components |
| `*View.swift` | Screens |

## Notes

- An in-progress workout is not restored if the app is force-quit; finished workouts, routines,
  custom exercises and settings are saved immediately.
- Weights are stored as typed, with the unit recorded per session.
