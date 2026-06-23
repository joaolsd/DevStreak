# DevStreak — Claude Code Setup Instructions

This file tells Claude Code exactly what to do to turn these source files
into a buildable Xcode project. Run these instructions from the repo root.

---

## Project structure expected

```
DevStreak/
├── DevStreak/                    ← main app target
│   ├── DevStreakApp.swift
│   ├── Models/
│   │   ├── AppConstants.swift
│   │   ├── CodingSession.swift
│   │   ├── DateHelpers.swift
│   │   └── StreakLogic.swift
│   ├── ViewModels/
│   │   └── StreakViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── DashboardView.swift
│   │   ├── HeatMapView.swift
│   │   └── SettingsView.swift
│   └── Notifications/
│       └── NotificationManager.swift
└── DevStreakWidget/              ← widget extension target
    └── DevStreakWidget.swift
```

---

## Steps for Claude Code

### 1. Create the Xcode project

```bash
# Use xcodegen or do this manually in Xcode:
# File → New → Project → iOS App
# Product name: DevStreak
# Bundle ID: com.yourname.devstreak      ← CHANGE THIS
# Interface: SwiftUI
# Storage: SwiftData
```

### 2. Add the Widget Extension target

In Xcode:
- File → New → Target → Widget Extension
- Product name: DevStreakWidget
- Include Configuration App Intent: NO

### 3. Configure App Group (required for widget ↔ app shared data)

In Xcode for BOTH targets (DevStreak + DevStreakWidget):
- Signing & Capabilities → + Capability → App Groups
- Add group: `group.com.yourname.devstreak`   ← match AppConstants.appGroupID

### 4. Enable Push Notifications capability (for local notifications)

Main app target only:
- Signing & Capabilities → + Capability → Push Notifications

### 5. Replace the bundle ID in AppConstants.swift

Edit `DevStreak/Models/AppConstants.swift`:
```swift
static let appGroupID = "group.com.yourname.devstreak"
//                               ^^^^^^^^
//                       Replace with your actual Apple Developer team bundle ID prefix
```

### 6. Copy source files into the Xcode project

Drag all `.swift` files from the directories above into the appropriate
Xcode target groups. Make sure:
- All files in `DevStreak/` are added to the **DevStreak** target
- `DevStreakWidget/DevStreakWidget.swift` is added to **DevStreakWidget** target only
- `AppConstants.swift` and `DateHelpers.swift` should also be added to
  the **DevStreakWidget** target (it needs the constants and date helpers)

### 7. SwiftData model container

`DevStreakApp.swift` already sets up `.modelContainer(for: CodingSession.self)`.
The widget reads only from shared UserDefaults (not SwiftData directly),
so no additional container setup is needed for the widget target.

### 8. Build and run

```
Cmd+B to build — resolve any signing issues in the Signing & Capabilities tab.
```

---

## What's NOT yet implemented (next steps)

- [ ] App icon and accent colour asset catalogue
- [ ] Lock Screen widget variant (.accessoryCircular / .accessoryRectangular)
- [ ] Onboarding / first-launch flow
- [ ] iCloud sync (CloudKit + SwiftData) — optional but natural next step
- [ ] Haptic feedback on goal completion
- [ ] Siri Shortcut for quick log ("Hey Siri, log 30 minutes")
