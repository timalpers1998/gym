# GymTracker

A personal iOS workout tracker built with SwiftUI, SwiftData, and Swift Charts.

## Features

- **Log workouts** — start a session, add exercises, record sets (reps × weight), and check sets off as you go. An in-progress workout survives app restarts.
- **Routines (templates)** — build routines like Push/Pull/Legs with per-set rep/weight targets, start workouts from them, or save a finished ad-hoc workout as a routine.
- **History & progress** — browse past workouts by month, see per-exercise charts (top-set weight, total volume, estimated 1RM) and personal records.
- **Rest timer** — auto-starts when you complete a set (configurable), with a live countdown bar and a local notification when rest is up.
- **Exercise library** — ships with ~70 common exercises grouped by muscle group; add your own custom exercises.

All data stays on-device (SwiftData). No account, no backend.

## Requirements

- **Xcode 16 or later** (the project uses the Xcode 16 project format with a filesystem-synchronized source folder)
- iOS 17.0+ (simulator or device)

## Getting started

```sh
git clone <this repo>
open GymTracker.xcodeproj
```

Select an iPhone simulator and press **Run** (⌘R). No signing is needed for the simulator.

Or from the command line:

```sh
xcodebuild -project GymTracker.xcodeproj -scheme GymTracker \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Running on your iPhone

1. In Xcode, select the **GymTracker** target → *Signing & Capabilities*.
2. Choose your personal team and change the bundle identifier (`com.example.GymTracker`) to something unique, e.g. `com.yourname.GymTracker`.
3. Select your device and Run.

## Notes

- **Free-team signing quirks (device installs):** if signing complains about the App Group capability, open *Signing & Capabilities* once for both the app and widget targets so Xcode registers `group.com.example.GymTracker`; if the group or bundle ID is reported as unavailable, rename both to something unique (e.g. `com.yourname.GymTracker` / `group.com.yourname.GymTracker` — keep the widget's bundle ID prefixed by the app's).

- **Weight units:** the kg/lb setting is a display label only — weights are stored exactly as entered and are not converted when you switch units.
- **Notifications:** permission is requested the first time a rest timer starts. If you decline, the in-app countdown still works.
- **Troubleshooting:** if the project ever fails to open in an older Xcode, either upgrade to Xcode 16+, or create a new iOS App project named `GymTracker` in Xcode and drag the `GymTracker/` folder into it — all source files live there.

## Project layout

```
GymTracker/
├── App/         App entry, root tab view, notification delegate
├── Models/      SwiftData models (versioned schema V1)
├── Seed/        Built-in exercise library + first-launch seeding
├── Services/    Rest timer, notifications, workout factory, progress math, settings
├── Features/    Workout / Templates / History / Exercises / Progress / Settings views
└── Shared/      Formatters and reusable UI components
```
