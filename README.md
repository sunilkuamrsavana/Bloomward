# Bloomward

## Daily planner update (October 10)

The live app now uses four native SwiftUI tabs: **Day**, **Routines**, **Notes**, and **Profile**. Profile is in the bottom navigation, not the top toolbar; Settings is reached from Profile. Main screens use compact inline titles, aligned lists, consistent section headings, and a compact date row on Day and Notes. Routines uses repeat-arrow symbols, with filled selected tab icons. The separate Habits and Insights sections, scenic headers, progress rings, and Quick Log are no longer part of the main app. A plain first-launch screen opens the empty planner without requiring an account.

- Day supports date navigation, one-off tasks, optional planning times, weekday repetition, completion/undo, partial completion, skipping, and explicit moves between dates. Unfinished tasks are not automatically carried forward.
- Routines are reusable checklists with nested step groups and optional weekday-specific steps. Add a checklist once or repeat it. Daily occurrences snapshot their title, steps, notes, and progress; later template edits do not overwrite captured checklists. No habit-linking UI is exposed.
- Notes supports multiple titled or untitled pages per date, local autosave, in-date search, recoverable Trash, and detection of an open note changing on another device. Conflicting text is retained in the editor for copying, rather than silently overwritten.
- Removed tasks and archived routines can be restored through Settings. Previous routine sessions remain accessible. An old active run can still be continued through a simple compatibility screen.
- Legacy habit IDs and daily completion entries remain intact on disk and in backups. They are represented as repeating tasks; compatibility records are not deleted. The first local upgrade keeps a pre-planner recovery copy in the appropriate guest/account storage scope.
- Cloud schema 3 includes tasks, daily occurrences, and notes. Schema 1/2 remain readable; older clients cannot overwrite a schema-3 backup. Guest and account data remain isolated, with an explicit additive import prompt. Active sessions, credentials, and notifications are not migrated into task data.

Verification: 105 core tests and 42 isolated backend tests pass, and the signed iOS simulator build succeeds. Logs and screenshots are under `work/planner-*`. Backend health and database readiness were checked after deployment. Simulator navigation through Day, Routines, Notes, Settings, and the blank note editor passed; closing a blank note created no page. Full interactive task/note editing acceptance, large-text, and physical two-device sync checks are still pending. Planning times do not promise notifications. Cloud snapshots currently have a 512-KiB total upload limit; oversized backups remain local and show a sync error.

The sections below document earlier implementation history and are retained as migration context, not the current product navigation.

Bloomward is a SwiftUI routine and habit tracker built around flexible follow-through rather than streak anxiety. The first development slice focuses on the daily loop: see what matters now, start a routine, complete or adapt each step, and recover without creating an overdue backlog. The project/scheme still use the working name Daymark. The app display name is Bloomward and its registered bundle ID is `com.inqox.bloomward` (team `A9N7R3TRCA`). This is a separate install from `com.example.daymark`: the old install and its data are not removed or silently migrated.

## Current scope

- Native SwiftUI application shell with Today, Routines, Habits, Insights, and Settings tabs
- Editorial nature-inspired visual system implemented with SwiftUI shapes and system typography
- Interactive routine runner presented full screen
- Routine timers that survive backgrounding and pause when deferred
- Quick habit completion and recovery states
- Pure Swift state/reducer layer with unit tests
- Offline-first persistence plus account-owned cloud sync for habits, routines, and history
- Reference-led first-use flow from the revised “Design new user screens” set: Welcome → starting choice → habit → setup → real Today
- Get Started begins local-first setup; Explore First and Maybe Later open the empty app, and Sign In stays available separately
- Persisted, back-editable onboarding draft; four suggestions, custom names, goal and weekday controls; no automatic habit selection or seeded history
- Optional routine preview shows all three steps before Add Routine creates them
- First-day Today has a centered live progress ring and Mark Done / undo; a dismissible, once-only backup offer follows the first real completion
- The backup path asks explicitly before copying local habits/history into an authenticated account; account-owned conflicts win and the local copy is preserved
- Empty Today screen with a working Create your first habit action, without seeded demo data
- Illustrated Today, Routines, and player layouts with a shared custom five-item bottom bar
- Routine-library search and filters; independent steps, embedded sub-routines, and optional reuse of existing habits
- In-app snooze and return-time scheduling; optional first-use local reminder requests iOS permission only after choosing a time and Add Habit
- Reference-led Insights with live weekly history, consistency and return scores, patterns, and streaks
- Full-screen New/Edit Habit form with icon, category, weekdays, time window, options, and notes
- Weekday scheduling and vacation pause filter the Today screen
- Reference-matched Habits library with All/Today/Paused filters, time-of-day groups, and live completion
- Reference-matched scenic Settings with optional profile name, week-start choice, new-habit defaults, and support information

Carry-forward, custom habit day rollover, and reminder styles are saved preferences only; their automation is not yet enabled. Insights shows insufficient-history states rather than fabricated scores. The recovery score describes returning to habits, not health or medical recovery.

The first-use reminder is separate from the editor's advanced reminder styles. It repeats on the first habit's selected weekdays and can be changed or disabled in Settings → Notifications. It is local to this device/profile, is cancelled when that habit is paused/archived or the active profile changes, and does not transfer during account import. Notification refusal never prevents habit creation. Physical-device delivery, larger accessibility sizes, and the full new-account backup handoff remain release checks. The OS launch screen uses text-free artwork, without an artificial splash delay.

The illustrated account-entry screen now connects to Clerk production through ClerkKit/ClerkKitUI 1.5.5. Apple's native button starts native Apple authorization. Email and Sign In open a themed Clerk form, including verification, password policy, recovery and MFA handling. Production currently requires a password at email sign-up (15-character minimum); email-code sign-in is also enabled. Only a completed, active, unexpired Clerk session selects account storage. Pending verification is not treated as success.

Settings includes account management, cloud sync status/retry, conflict review, and sign-out. Guest habits and each Clerk account's habits/preferences use separate on-device storage; signing in does not automatically merge guest data. Signing out keeps unsynced changes for that account on this iPhone. Clerk owns credential persistence in Keychain; the app does not store tokens with habits. Signed-in accounts sync to the authenticated Cloudflare API; guest mode stays local-only. Terms and Privacy links still show development-build information; real policies are required before public release. See [sync behavior and operations](backend/SYNC.md).

The illustrated references guide screen content. The separately supplied navigation reference guides only the bottom bar. Data such as habit counts, steps, and timers stays live rather than being copied from the reference images.

## Requirements

- Xcode 26 or newer (Swift 6.2+ for Clerk)
- iOS 17 or newer

Open `Daymark.xcodeproj` and run the `Daymark` scheme on an iPhone simulator.

Core logic can be checked without Xcode:

```sh
swift test
```

For isolated simulator UI testing, launch the Debug build with `--ui-testing`. It starts with empty in-memory habits and separate temporary preferences, without initializing Clerk or accessing credentials. Login actions explain that real sign-in is disabled; they never simulate success. Relaunch normally to test production authentication. Sample data is limited to developer previews; normal fresh installs start empty.

Keep simulator code signing enabled (local ad-hoc signing is sufficient). `CODE_SIGNING_ALLOWED=NO` removes the simulator identity entitlement and causes Clerk initialization to fail with Keychain error -34018. The signed build runs on the existing iPhone 17 Pro / iOS 26.2 simulator. The user confirmed successful sign-in. The 52 core tests pass, including onboarding validation/draft serialization, explicit import, isolated storage, cloud merge and restore. Automated backend tests cover sync and deletion with isolated test identities; no real account was deleted for testing. Physical two-iPhone acceptance testing remains a release check.

The Clerk form is constructed once per presentation because its identifier-persistence opt-out writes UserDefaults during initialization. Reconstructing it in a SwiftUI body while Settings' `@AppStorage` is mounted causes a render loop on the tested simulator. Account storage is also initialized lazily once per account, and both welcome and Settings present login from the same root.

Final UI checks: Settings → login → email form, close, reopen using Sign In, and close all passed after that fix. The live form showed email and Apple only after disabling Google. Empty guest home and relaunch persistence were also checked. These checks stop before entering real credentials or sending verification emails.

Onboarding simulator checks (September 22): both starting choices and routine preview; disabled Continue before selection; changed goal and repeat day; Add Habit creates only the selected pending habit; Mark Done / undo update the ring; Not Now preserves completion; custom name validation and back-navigation draft retention; Maybe Later opens an empty app without the unsaved draft. Checked in isolated UI-testing mode, without using the real account or requesting notification permission. Screenshots and build/test logs are under `work/onboarding-*`.

At the end of the onboarding checks, a normal relaunch displayed local mode. The existing account preferences and guest preferences are still present, and no sign-out, account deletion, or data reset was performed. Revalidating session restoration is a follow-up; the new backup-to-account handoff has unit coverage but has not been exercised with real credentials. That earlier handoff used an isolated first-launch preview; the latest library-fix handoff below replaces it with a normal persistent launch.

## Architecture

Routine structure and reference restoration (September 23): the builder now offers Add step and Add sub-routine. Ordinary actions do not create habit records; Use an existing habit is optional and shares daily completion. Embedded groups can contain further groups (up to five item levels). Routines and items optionally choose days and a planning time; omitted item schedules inherit the parent's days, while explicit days intersect them. Empty groups and incompatible schedules cannot save. The routine detail sheet exposes Edit, preserves stable IDs, and shows the hierarchy. The runner snapshots only the eligible leaf steps on start, displays the current sub-routine path, and preserves that plan through edits, pause/resume, and restart. The Today filter includes eligible routines, and off-day routines cannot start an empty run. Existing flat routines, daily history, and active runs remain readable.

Today and Insights now place progress rings across the landscape boundary, rather than below a generic header card. Today has a compact one-habit check-off row and fixed-width cards for multiple Quick Log items. Quick Log and Next are disjoint, with future timed habits in Next and consistent placement after completion. The selected filled tab icons and native top-right library Add controls are unchanged. No illustration asset was regenerated.

Verification: 82 Swift core tests and 38 isolated Workers tests pass. Simulator review used a separate `com.inqox.bloomward.review` app with empty, in-memory state: created a weekday-only sub-routine with an independent timed action, saved and completed it, confirmed the Habits library stayed empty, created a standalone review habit, and inspected Today/Insights. Largest Dynamic Type creation controls were checked; normal text size and keyboard capture were restored. Normal user data is not used for mutation tests. The temporary review app was removed. The final signed normal build is installed with the existing Workout preserved; screenshots are `work/routine-today-final.png`, `work/routine-insights-final.png`, and `work/routine-builder-final.png`. Build/test logs: `work/routine-*`. Cloud wire schema 2 preserves nested steps and blocks older schema writes; details are in `backend/SYNC.md`.

Selected navigation icons (September 23): each active tab now fills the icon's interior in green, while inactive icons remain gray outlines. The routine page retains cutout text lines, the habit leaves and insight bars are solid, and Settings uses the matching filled gear. Icon identities, hit targets, labels, and tab-bar placement are unchanged. The signed simulator build passed and all five selected states were checked in the normal persistent app without changing habit data. Screenshots are under `work/tab-icon-fill-*`.

Library action placement (September 23): Habits and Routines use the same native top-right Add action, available while scrolling. Their empty-state cards offer Create your first habit/routine; both entry points use the same screen-owned creation flow. The full-width creation strips above the tab bar are removed, with the five navigation destinations and form Save actions unchanged. Accessibility-sized filter pills scroll horizontally rather than splitting words, and the library header's text protection scales with Dynamic Type. The 70 core tests and signed iOS build pass. Isolated simulator checks covered both empty-state actions, saving a habit and a linked routine, the populated-library toolbar, cancelling creation without extra records, and opening Add after scrolling at the largest accessibility text size. Simulator text size and keyboard capture were restored after testing. The normal persistent app, not the isolated preview, is the final install; account and guest data are preserved.

Habit visibility and compact libraries (September 22): Habits now defaults to All, rather than hiding off-day habits behind Today. Saving a habit returns to All, new habits default to every day with no time window, and existing schedules remain unchanged. Both libraries use shorter illustrated headers and compact rows; routine steps open in a separate detail sheet. Habits remain independent records, routines link their IDs, and renaming a habit updates linked routine step labels. New routines also return the library to All. All 70 core tests pass, including 9 habit-library/connection regressions. Isolated simulator checks covered direct creation, Saturday-only creation while viewing Today, automatic return to All, two routines reusing the same habit without duplicates, editing through routine details, and routine completion updating the habit library. The signed iOS build passed. The normal `com.inqox.bloomward` app is installed and running without `--ui-testing`; the user-approved two Workout habits and Morning flow from the old in-memory preview were discarded, and the separate review app was removed. No persistent account/guest records or cloud services were reset. Review screenshots and logs are under `work/library-*`; the installed screenshot includes the final header-contrast adjustment.

Design consistency and routine creation (September 22): Today, Routines, Habits, Insights, Settings, and the New Habit/New Routine forms share the scenic header, serif section headings, soft cards, and green action styles. Original illustration assets and bottom navigation are retained. Add Routine is always available above the tab bar. Its builder can reuse existing habits, create new habits, reorder steps, and remove draft steps. New habits and the routine save atomically; cancelling does not alter the library. Habit rows show their linked routines, and routine cards expose their ordered habits. Completing a routine step updates the same habit's daily log. Today no longer repeats its featured routine as a fictional 8 PM item or lists completed habits as upcoming. The 61 core tests pass, including 9 routine-draft tests; isolated simulator checks covered creation from an empty library, reordering, existing-habit selection, cancellation, linked completion, and all five tabs. Account data and cloud services were not changed.

Habits layout refinement (September 22): the scenic header retains the lake; habit rows and form labels use readable, Dynamic Type-aware text. Add Habit is anchored in the same bottom container as navigation, avoiding nested inset overlap, and the New/Edit form scrolls with a persistent Save action. Empty libraries show one invitation instead of a redundant progress card. The form uses full-size switches and weekday targets; long category lists scroll horizontally. Advanced preferences remain honestly labeled as not automated. Simulator checks covered isolated creation, daily scheduling, editing, completion/undo, scrolling through Notes, and the Paused filter; no user or cloud records were modified.

- `RoutineCore/` contains dependency-free domain models and state transitions.
- `Daymark/App/` contains the application entry point and observable UI model.
- `Daymark/UI/Theme/` and `Daymark/UI/Components/` contain reusable presentation primitives.
- `Daymark/UI/Screens/` contains feature screens.

## Backend and account setup

Bloomward's Cloudflare Worker, isolated D1 database, and Clerk production instance now exist. The domain is `bloomward.inqox.com`, with the API at `api.bloomward.inqox.com`. No paid Clerk upgrade was made. See [backend setup and remaining release checks](backend/README.md).

Authentication and cloud sync are implemented. The backend verifies every session and derives ownership from the verified account, never from caller-supplied IDs. Changes sync while the app is active and reconnect automatically after offline use. Competing edits require explicit review instead of silently overwriting progress. Active timers and device-specific settings remain local.

The cloud-sync backend is deployed, and the updated simulator app successfully synced the user's existing signed-in account on September 22, 2026. Settings displays `Up to date` and the last successful sync time. No demo habits were added, no account was deleted, and existing simulator data was preserved.
