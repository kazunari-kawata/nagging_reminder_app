# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Baddger** — an iOS task reminder app whose hook is *nagging notifications*: each task fires a base notification at its scheduled time and then a chain of follow-up reminders at a user-defined interval until the task is completed. SwiftUI-only, Swift 5, targets iOS 26.2+ (Xcode 26+). Bundle ID: `bridgesllc.co.jp.nagging-reminder-app`.

## Build / Run / Test

`build.sh` (zsh) runs the full simulator round-trip: `xcodebuild` → `simctl boot` → `simctl install` → `simctl launch`.

```bash
./build.sh          # incremental
./build.sh clean    # clean build (any non-empty arg triggers clean)
```

Edit the variables at the top of `build.sh` if your simulator name differs from `iPhone 17 Pro`. Verify with `xcrun simctl list devices`. Derived data is written to `./build/` (committed; safe to delete).

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. Suites cover Codable round-trip (`RepeatScheduleTests`), legacy-key migration (`TaskItemMigrationTests`), and the IAP error model (`PurchaseErrorTests`); shared tags (`.codable`, `.migration`, `.purchases`) live in `TestTags.swift`. The test target uses an Xcode synchronized folder group, so any new `.swift` file dropped into `nagging_reminder_appTests/` is auto-included — no `.pbxproj` edit needed. Run via Xcode (`⌘U`) or:

```bash
xcodebuild test -scheme nagging_reminder_app \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath ./build
# Single suite:
xcodebuild test ... -only-testing:nagging_reminder_appTests/RepeatScheduleTests
# By tag (e.g. all migration tests):
xcodebuild test ... -only-test-tag:migration
```

New suites should stay pure-data — `TaskManager` and the other managers touch `UserDefaults.standard` and `UNUserNotificationCenter.current()` in their initializers, so testing them parallel-safe needs DI (not yet wired up).

There is no separate lint step — Xcode's compiler warnings are the bar.

## Architecture

Single-target SwiftUI app. The entry point `nagging_reminder_appApp.swift` instantiates seven `@Observable` managers as `@State` and injects them via `.environment(...)`; views read them with `@Environment(Type.self)`. **All state flows through this DI graph — do not reach into `UserDefaults` or singletons from views.**

Manager responsibilities:

| Manager | Responsibility | Persistence |
| --- | --- | --- |
| `TaskManager` | Task CRUD, all `UNUserNotificationCenter` scheduling, history archive, midnight reset | `UserDefaults` keys `savedTasks_v2`, `taskHistory` |
| `AppSettings` | Theme, week-start, onboarding flags, review-prompt counters | `UserDefaults` (one key per property, set in `didSet`) |
| `TimerManager` | Workout/break timer presets | `UserDefaults` `timerPresets` |
| `NotificationDelegate` | `UNUserNotificationCenterDelegate` — routes SNOOZE_1HR / DONE / tap actions back into `TaskManager`; tap target surfaces via `tappedTaskID` which `ContentView` observes | none |
| `InterstitialAdManager` | AdMob interstitials, gated by 7-day grace + ≥3 completed tasks + 10-min cooldown | `UserDefaults` `interstitialLastShown`, `firstLaunchDate` |
| `PurchaseManager` | StoreKit 2 ad-free IAP; `@MainActor`, listens to `Transaction.updates` | StoreKit entitlements |
| `ReviewManager` | `SKStoreReviewController` prompt; gated by ≥5 completions + ≥10 launches + 120-day cooldown | via `AppSettings` |

Data flow for a completed task: `TaskCardView` swipe → `taskManager.completeTask` → archives if non-repeating, cancels notifications, fires `onTaskCompleted` callback → `AppSettings.completedTaskCount++` → `ReviewManager.requestReviewIfAppropriate` + `InterstitialAdManager.showIfReady`.

### Notification scheduling (the most load-bearing logic)

`TaskManager.buildAndScheduleNotifications` is where most subtle bugs live. Key invariants:

- **iOS hard-caps pending notifications at 64 per app.** The "nag chain" budget is `(62 - taskCount) / taskCount` per task — adding/editing/deleting any task calls `rescheduleAllNotifications()` to rebalance. Don't bypass this.
- Notification IDs follow `{taskUUID}_{suffix}` (`_0`, `_wd_{1-7}`, `_nag_{i}`, `_snooze_{epoch}`). Stored on `TaskItem.pendingNotificationIDs` so `cancelNotifications` can remove only this task's requests.
- `nagChainBaseDate` returns the *next* fire date when the task's time-of-day has already passed today; otherwise today's time. This is what fixes the "create a task whose time already passed today and get an immediate notification storm" bug (commit `efa9733`).
- All schedule cases use `UNCalendarNotificationTrigger` with `repeats: true` for the base trigger, plus non-repeating triggers for the nag chain.

### Repeat schedules

`RepeatSchedule` is a Codable enum with cases: `once`, `daily`, `weekdays` (Mon–Fri), `selectedWeekdays(weekdays:[Int], time:)`, `weekly`, `monthly`, `yearly`. **Weekday integers are 1=Sun…7=Sat (Apple's convention).** Custom Codable encodes the case name as a `type` discriminator string; new cases must be added to both `encode(to:)` and `init(from:)`.

`TaskItem` has migration fallbacks in `init(from:)` for legacy keys `isDaily` (Bool) and `nagInterval` (Int rawValue). Keep these — there are existing installs with that data.

### Section grouping in `ContentView`

The task list is split into OVERDUE / TODAY / TOMORROW / THIS WEEK / LATER using `taskManager.isApplicableToday` + `nextOccurrenceDate`. A completed repeating task moves out of TODAY by skipping today in `nextFireDate`. A `uniqueTasks` filter dedupes by `(name, schedule)` hash — this guards against the duplicate-on-re-add bug; keep it if you change the list source.

## Conventions

- **`@Observable` + `@Environment` everywhere.** No `@StateObject` / `@ObservedObject` / `Combine` `ObservableObject`. Don't introduce them.
- **Two-space indent**, opening brace on same line, trailing closures. Match existing files.
- **All user-facing strings via `String(localized: "key")` or `LocalizedStringResource("key")`** — keys live in `Localizable.xcstrings` (Xcode String Catalog). The app ships with multiple locales; never hardcode UI strings.
- **AdMob IDs**: `#if DEBUG` uses Google's official test ID; release uses the production ID. Don't ship a real ID under DEBUG.
- **IAP product ID**: read from `Info.plist` key `ADFREE_PRODUCT_ID` (currently `no_ads`) via `PurchaseConfig.adFreeProductID`. Don't hardcode.
- Persistence happens in `didSet` on the manager properties — assigning the array re-saves. Avoid mutating in place if you need a save (or call `save()` explicitly).

## SwiftUI gotchas (learned the hard way)

`ANIMATION_DEBUG_LOG.md` documents a multi-day debugging session. The constraints to respect:

1. **Never use `return` inside a `@ViewBuilder` body** — Swift treats it as a normal function return and silently drops the DSL, producing a blank screen on device while the simulator looks fine.
2. **Multiple sibling `.fullScreenCover` modifiers can deadlock rendering on device.** The current app uses two top-level covers driven by `privacyNoticeAccepted` / `tutorialCompleted`; if you add a third in the same hierarchy, test on real hardware.
3. **`let _ = print(...)` works inside `var body: some View`** but breaks `some View` computed properties with an opaque-return-type error — use `.onAppear { print(...) }` there.
4. **Test on a real device, not just the simulator** — several rendering issues only reproduced on hardware.

## Release info

Version 1.1.0 (build 2). Distribution via App Store; metadata in `app_store_metadata.csv`. Sound asset: `baddger-sound.mp3` (also duplicated inside the target).
