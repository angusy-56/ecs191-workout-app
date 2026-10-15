# Workout

A small, clean iOS workout tracker built with Swift and SwiftUI. It tracks strength and cardio
sessions, rest timers, a weekly streak and a weekly calorie goal. There are no accounts, no
subscriptions and no network calls: everything is stored on the device.

---

## Building the app

### Requirements

| Tool | Version |
|---|---|
| macOS | A version that supports Xcode 16 |
| Xcode | 16 or newer |
| iOS | 17.0 or newer (simulator or device) |

No package managers, third-party libraries or backend are needed. There is nothing to install
besides Xcode.

### 1. Get the code

```bash
git clone https://github.com/angusy-56/ecs191-workout-app.git
cd ecs191-workout-app
```

### 2. Open the project

```bash
open Workout.xcodeproj
```

The project has two targets:

- **Workout**: the app (select this scheme to run).
- **WorkoutWidget**: the home-screen "Start Workout" widget. It is embedded in the app and builds
  automatically with it.

### 3a. Run on the iOS Simulator (easiest)

1. In the Xcode toolbar, choose the **Workout** scheme.
2. Pick any iPhone simulator (for example *iPhone 16 Pro*).
3. Press **Run** (⌘R).

The simulator does not need a signing team. The app launches with empty data; create a routine or
pick a starter routine from the **+** button on the Workouts screen.

### 3b. Run on your own iPhone

Running on a device needs a signing team because the app and widget share data through an App Group.

1. Plug in your iPhone and trust the computer. Turn on **Developer Mode** on the phone
   (Settings > Privacy & Security > Developer Mode).
2. In Xcode, select the project, then each target (**Workout** and **WorkoutWidget**), open
   **Signing & Capabilities**, and:
   - tick **Automatically manage signing**,
   - choose your **Team** (a free personal team works).
3. **Change the identifiers so they are unique to you.** Apple will refuse an identifier that
   another developer already registered. Use the same prefix for all three values:

   | Where | Default | Example replacement |
   |---|---|---|
   | Workout target > Bundle Identifier | `com.angusy.Workout` | `com.yourname.Workout` |
   | WorkoutWidget target > Bundle Identifier | `com.angusy.Workout.Widget` | `com.yourname.Workout.Widget` |
   | App Group | `group.com.angusy.Workout` | `group.com.yourname.Workout` |

   The widget's identifier must start with the app's identifier. The App Group name appears in
   three places; update all of them to the same new value:
   - `Workout.entitlements`
   - `WorkoutWidget.entitlements`
   - `Shared/SharedWorkouts.swift` (the `group` constant)
4. Choose your iPhone as the run destination and press **Run** (⌘R).
5. The first time, the phone may say the developer is untrusted. Go to
   Settings > General > VPN & Device Management and trust your developer profile.

> With a free personal team, an installed build expires after 7 days; run it from Xcode again to
> refresh it.

### Build from the command line

Simulator (no signing needed):

```bash
xcodebuild -project Workout.xcodeproj -scheme Workout \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

Compile check for a real device (no signing, no install):

```bash
xcodebuild -project Workout.xcodeproj -scheme Workout \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

The built app is placed under `build/Build/Products/`. The `build/` folder is git-ignored.

### Adding the widget

Once the app is installed, long-press the home screen, tap **+**, search for **Workout**, and add
the small or medium **Start Workout** widget. The medium widget lists your last three logged
routines; tapping one starts it.

### Troubleshooting

| Problem | Fix |
|---|---|
| "Failed Registering Bundle Identifier" | The identifier is taken. Change it to something unique (step 3 above). |
| "No profiles for ... were found" | Select a Team under Signing & Capabilities for **both** targets. |
| App Group / entitlement error | Make sure the App Group name is identical in both `.entitlements` files and `SharedWorkouts.swift`, and that both targets use the same team. |
| Widget shows generic text, not routines | Open the app once after installing so it can publish your routines; then re-add or refresh the widget. |
| Notifications do not appear | Allow notifications when prompted (first time a rest timer starts), or enable them in iOS Settings. |
| Simulator is slow to react | Wait a moment between taps; the first launch builds caches. |

---

## Using the app

- **Workouts**: tap **+** to start from a blank workout or a starter routine (Push, Pull, Legs,
  Upper Body, Lower Body, Full Body). Name it, add exercises from the library (grouped by muscle
  group, with equipment) or type a new name to create a custom exercise, and set the number of sets.
- **Start** a routine to log it. Weights and reps are prefilled from your last session. Tap the
  circle to complete a set; a rest timer starts automatically (−15 / +15 / Skip) and you get a
  notification when it ends. **Finish** saves only the completed sets.
- **Cardio**: choose one of 12 activities and an effort level (Easy, Moderate, Hard, Very Hard),
  then run a timer or enter the details manually. Calories are shown as an estimate.
- **History**: all strength and cardio sessions, newest first. Swipe to delete.
- **You**: this week's calories as a ring toward your weekly goal, your current streak, and a
  Monday to Sunday bar with a flame on each day you saved a workout. The gear (top right) opens
  **Settings** (units, age, height, weight, weekly calorie goal, rest time).

### How calories are estimated

- **Cardio**: MET value (by activity and effort) x your weight x hours.
- **Strength**: resting energy (Mifflin-St Jeor, sex-neutral) x 5 MET x workout duration.

Both are rough estimates. Add your weight in Settings to see them.

---

## Project layout

| Path | Purpose |
|---|---|
| `Workout/Models.swift` | Data types, exercise library, starter routines, cardio activities, calorie estimates |
| `Workout/Store.swift` | Saved data (JSON in the app's Documents folder) and weekly totals |
| `Workout/ActiveWorkout.swift` | State and timers for the workout in progress |
| `Workout/Notifications.swift` | Rest-timer local notifications |
| `Workout/Streak.swift` | Weekly streak logic and the Monday to Sunday bar |
| `Workout/CardioView.swift` | Cardio logging flow |
| `Workout/YouView.swift` | You dashboard and activity ring |
| `Workout/Theme.swift` | Fonts, colors, spacing, shared components |
| `Shared/SharedWorkouts.swift` | Data shared between the app and the widget |
| `WorkoutWidget/` | The home-screen widget |

## Notes

- Data is saved on the device only. Deleting the app deletes its history.
- An in-progress workout is not restored if the app is force-quit; finished sessions, routines,
  custom exercises and settings are saved immediately.
- Weights are stored as typed, with the unit recorded per session.
