# Handoff: liftIQ — iOS Workout Tracker

## Overview

liftIQ is a personal, offline-first workout tracker for iPhone: unlimited workout templates, spreadsheet-style set logging, full analytics, a "Splits" feature that groups templates into an ordered training cycle (with streak protection on rest days), and local notifications. No accounts, no cloud, no subscriptions.

**Target platform: native Swift + SwiftUI, iOS 18+, iPhone only, SwiftData for persistence.** Full functional requirements are in the bundled `Personal_Strong_Clone_App_Spec.md`; this README covers the approved visual design and the feature decisions made during design review.

## About the Design Files

The files in this bundle are **design references created in HTML** — mockups showing intended look and content, not production code. Your task is to **recreate these designs in SwiftUI** using native patterns (TabView, NavigationStack, List/ScrollView, Swift Charts, UNUserNotificationCenter). `Workout Tracker Directions.dc.html` contains every approved screen rendered inside iPhone frames (`ios-frame.jsx` is just the device-bezel scaffold — ignore it). The approved design is **turns 2–4** (sections `t2`, `t3`, `t4`, at the top of the file). Turn 1 contains earlier explorations — ignore except as context; the chosen direction was "1b Pro Data" surfaces + "1a" spreadsheet logging grid.

## Fidelity

**High-fidelity.** Colors, typography treatment, spacing, and copy are intentional. Recreate faithfully, but always prefer the native SwiftUI equivalent (system materials, SF symbols, standard toggles/pickers) over pixel-exact imitation of the HTML — e.g. use real `Toggle`, segmented `Picker`, `.searchable`, and the system tab bar.

## Design Tokens

Colors (dark mode only for v1; a Light/Dark/System setting exists but Dark is the designed theme):
- App background: `#050507` (near-black)
- Card surface: `#101014`, corner radius 12–16, hairline border `0.5px rgba(255,255,255,0.09)`
- Elevated/inset control: `rgba(255,255,255,0.06–0.08)`
- Accent (interactive, links, active tab, primary buttons): iOS blue `#0A84FF`
- Success / completed sets / streak-safe: `#30D158` (completed set rows get a `rgba(48,209,88,0.07)` row tint)
- Warm-up set marker + PR gold: warm-up `W` in `#FF9F0A`; PR badges/1RM chart in `#FFD60A`
- Destructive: `#FF453A`
- Text: white; secondary `rgba(255,255,255,0.45–0.6)`; tertiary `rgba(255,255,255,0.35–0.4)`
- Hairline separators inside cards: `rgba(255,255,255,0.08)`

Typography:
- UI text: SF Pro (system font). Large titles 34/bold; screen headers per iOS conventions; body 15–17; secondary 12–13.
- **All numerals and data labels: SF Mono** (`.monospaced` design) — stats, timers, volumes, dates like `MON JUL 6 · WEEK 27`, section eyebrows like `★ FAVORITES`, `CYCLE · 4 DAYS`. Eyebrow labels are 11px/semibold, letter-spacing ~1px, uppercase, 40% white.
- Wordmark: "lift**IQ**" — "lift" white, "IQ" in accent blue, both bold 34.

Spacing & shape:
- 16px horizontal screen margins; 8–12px gaps between cards; card padding 13–18px.
- Buttons: 12px radius, 44px+ hit targets. Pills/chips: 10px radius.
- Charts: minimal Apple-Health-style line charts, 2.5px stroke, faint horizontal gridlines `rgba(255,255,255,0.06)`, end-point dot, no fills/glows. Volume chart blue, est-1RM chart gold, body weight green.

Tab bar: standard iOS tab bar, 5 tabs — Home, Workouts, Templates, Progress, Settings. Active = blue icon+label. Use SF Symbols (`house.fill`, `dumbbell.fill`, `folder.fill`, `chart.bar.fill`, `gearshape.fill` or similar).

## Screens

### Home (design ids `2a`, superseded by `3c` once splits exist)
- Wordmark header + mono subline: date, active split name, cycle position (`MON JUL 6 · PPL + REST · DAY 2/4`).
- **Hero card** (blue hairline border):
  - If a workout is in progress: `IN PROGRESS · 32:14` eyebrow, workout name, `3/5 exercises · 6,240 lbs so far`, blue **Resume** button.
  - Otherwise: `UP TODAY · FROM YOUR SPLIT` eyebrow, today's template name, `5 exercises · ~55 min · next: Legs`, blue **Start** button.
- Two secondary buttons: `+ Empty Workout`, `From Template`.
- Three stat tiles (mono numerals): CYCLE `2/4` with 4-segment progress bar (done=green, today=blue, upcoming=10% white) · STREAK `46d` with "rest-day safe" caption in green · BODY WT `182.4` with weekly delta (`▼ 0.8 this wk`, green when trending toward goal).
- "Recent" list: workout cards with name (+ small blue `DAY n` split tag), mono meta line `YDA · 52:08 · 12,410 LB`, gold `1 PR` badge when applicable. Automatic rest days appear as dimmed "Rest Day" rows with `SAT · STREAK KEPT` and a moon glyph.

### Active Workout (`2b`) — the core screen
- Header: workout name (22/bold), mono date/start-time line, blue **Finish** button (top-right).
- Stat strip (mono): TIME 32:14 · VOLUME 6,240 · SETS 9/16 · REST 1:12 (rest in blue, right-aligned).
- Rest-timer bar: thin blue progress track in a `rgba(10,132,255,0.12)` strip with `+30s` and `Skip` text buttons. (Timer is also a settings-driven auto-start.)
- **Exercise card** with spreadsheet logging grid. Grid columns: `SET | PREVIOUS | LBS | REPS | ✓` (mono uppercase header, 11px). Rows:
  - Warm-up sets show `W` in orange instead of a number.
  - Completed rows: green row tint + solid green check button (30×30, radius 8).
  - Current row: blue row tint + 2px blue left edge; the active input field gets a blue border.
  - Pending rows: values shown dimmed (35% white) as autofill suggestions from previous performance; PREVIOUS column shows e.g. `185 × 8`.
  - `+ Add Set` full-width quiet button (blue text) at card bottom.
- Card header row: exercise name (17/bold) + equipment in 40% white, gold mono `1RM 218` chip, ellipsis menu (notes, history, records, replace, reorder, delete, duplicate).
- Collapsed upcoming exercise cards: name + `0/3` set count. Dashed-border `+ Add Exercise` button at bottom.
- Set types: normal, warm-up (`W`), failure, drop set — selectable via tapping the set-number cell. RPE and per-set notes available from the row.

### Workouts / History (`2c`)
- Large title, search field ("Search workouts, exercises, notes").
- Month group headers in mono: `JULY 2026 · 3 WORKOUTS`.
- Workout cards: name + gold PR badge + chevron; mono meta `SUN JUL 5 · 58:12 · 14,230 LB · 21 SETS`; exercise summary line in 55% white (`Deadlift 4×5 · Barbell Row 4×8 · …`). Swipe/context actions: edit, duplicate, delete.

### Templates (`2d`, superseded by `3a`)
- Large title + blue `+` round button (new template / new split / new folder).
- **MY SPLIT card** (blue hairline border) at top: split name, mono `4-DAY CYCLE · DAY 2 OF 4`, blue **Edit** link; horizontal day chips — completed day (green tint + check), today (blue tint + border + `TODAY`), upcoming (neutral, weekday captions); footer strip: star icon + "Streak follows this split — rest days count as on-track" + green mono streak count.
- `+ New Split` dashed button.
- `★ FAVORITES` section: template cards with name, `5 exercises · in PPL + Rest` (or `last used …`), gold star, blue **Start** chip button.
- Folder sections (mono eyebrow `📁 PPL SPLIT · 6`): grouped list rows — name, exercise count, chevron.

### Split Builder (`3b`) — modal sheet
- Nav: Cancel / "Edit Split" / Save.
- Name field card.
- `CYCLE · 4 DAYS` list: numbered rows (blue number chip) with template name + `Template · 5 exercises`, drag handles to reorder; Rest Day rows use a moon chip and caption "Counts as on-track". Swipe to delete.
- Two add buttons: `+ Template Day` (blue tint) and `+ Rest Day` (neutral).
- `STREAK RULES` card:
  - **Streak follows this split** toggle — "Rest days in the cycle keep the streak alive".
  - **Flexible order** toggle — "Any day from the cycle counts, in any order".

### New Exercise (`4a`) — modal sheet
- Nav: Cancel / "New Exercise" / Save (disabled until name entered).
- Name field; TYPE chip row (single-select): Bodyweight + reps, Weight + reps, Reps only, Duration, Distance, Assisted (full list per spec: weight+reps, weight only, reps only, duration, distance, bodyweight, assisted, machine, cable, custom).
- DETAILS rows → pickers: Equipment, Primary muscles, Secondary muscles.
- Optional notes/instructions text area.
- Also reachable from exercise search: an "Add '\<query\>'…" row at the bottom of search results.

### Progress (`2e`)
- Large title; range chips `3M / 6M / 1Y / All` (selected = white bg, black text).
- Three stat tiles: WORKOUTS 148 (`4.1/wk avg`) · STREAK 11wk (`longest 14`) · AVG TIME 57min.
- Chart cards: "Total volume · weekly" (blue line, big mono current value, green `+8.2%` delta, mono month axis) and "Bench Press · est. 1RM" (gold line, `+12`). Exercise chart is swappable per exercise.
- Row links: Body weight (current value + chevron) and Personal records (count + chevron).

### Settings (`2f`) + Notifications subpage (`4b`)
- Grouped cards under mono eyebrows:
  - UNITS: Weight lbs/kg, Distance miles/km, Time 12h/24h — segmented controls.
  - APPEARANCE: Theme Light/Dark/System segmented.
  - REST TIMER: Default duration (2:00, picker), Auto-start after set, Sound, Vibration toggles.
  - NOTIFICATIONS: link to subpage.
  - DATA: "Export all data as CSV" (blue), "Reset app data…" (red, confirmation alert).
- Notifications subpage: master "Allow notifications" toggle ("All reminders are generated on-device"); WORKOUT group — Rest timer done, Daily workout reminder ("Up today: X" from split), Reminder time (8:00 AM), Skip on rest days; STREAK group — Streak at risk ("Evening nudge if a scheduled workout is unlogged"), Nudge time (7:00 PM). A sample banner preview is shown in the mock: "Up today: Pull Day B — 5 exercises, ~55 min. Day 2 of your PPL + Rest cycle."

## Interactions & Behavior

- **Logging autofill**: new sets pre-fill from the same exercise's previous workout (shown dimmed); tapping ✓ commits the values and starts the rest timer (if auto-start on). Number pad input for weight/reps.
- **Rest timer**: per-exercise or default duration; runs while app is backgrounded; fires a local notification + sound/vibration when done; +30s and Skip controls.
- **Elapsed workout time** ticks live in the header/stat strip.
- **Splits & streak (core logic)**:
  - A split is an ordered cycle of days; each day = a template or Rest. Cycle position advances when a day is satisfied; the cycle wraps.
  - **Rest days are automatic**: a calendar day with no logged workout counts as a rest day. If the split scheduled Rest that day, the streak is kept (history shows a dimmed "Rest Day · streak kept" row). If the split scheduled a workout and none was logged by end of day, the streak breaks.
  - Streak is counted in days when a split is active. "Streak follows this split" toggle off → streak falls back to weekly-goal-based counting.
  - **Flexible order** on → any not-yet-done template from the current cycle satisfies the day; Home would show remaining days rather than a strict "day n".
  - Logging a workout started from a split-day template marks that cycle day complete; ad-hoc workouts count for "any workout" streak purposes but don't advance the cycle unless flexible order matches them.
- **Notifications** (all local via `UNUserNotificationCenter`, no server): rest-timer completion (scheduled when timer starts); daily reminder at user time, content generated from the active split, suppressed on scheduled rest days; streak-at-risk nudge at user time, only if that day scheduled a workout that isn't logged. Re-schedule pending notifications whenever the split, history, or settings change.
- **PR detection** on workout finish: highest weight, highest volume, most reps, best est. 1RM (Epley: `w × (1 + reps/30)`), longest workout, largest volume workout, longest streak. Surface as gold badges on history/home and in a records list.
- Deletes (workouts, templates, splits, custom exercises) get confirmation; reset-app-data double confirmation.

## State & Data

SwiftData models per the spec's Data Model section (Workout, Exercise, WorkoutExercise, Set, Template, Measurement, PersonalRecord), plus:

- `Split`: id, name, isActive, streakFollowsSplit: Bool, flexibleOrder: Bool, days: [SplitDay]
- `SplitDay`: order: Int, kind: .template(templateID) | .rest
- Derived/stored: current cycle index, streak count, longest streak.
- `NotificationSettings` (or UserDefaults): master toggle, per-type toggles, reminder time, nudge time, skipOnRestDays.
- Active workout state must survive app kill (persist in-progress workout).

## Exercise Database (seed)

Ship a bundled JSON seed of ~200 common exercises — fields: `name`, `type` (one of the 10 set-tracking types), `equipment`, `primaryMuscles`, `secondaryMuscles`, `instructions` (2–4 short steps). Import into SwiftData on first launch (idempotent, keyed by stable ids). Built-ins can be hidden/restored but never deleted; custom exercises are flagged `isCustom` and behave identically (history, charts, PRs). **Generate this seed file as part of implementation** — cover barbell/dumbbell/machine/cable/bodyweight staples across all major muscle groups.

## Assets

No image assets. Icons in the mocks are simple placeholder glyphs — use **SF Symbols** throughout (moon for rest, star for favorites/streak, folder, chart, gear, checkmark, ellipsis, drag handle `line.3.horizontal`). App icon: not designed yet; a simple "IQ" monogram on blue was used in the notification preview.

## Files in this bundle

- `Workout Tracker Directions.dc.html` — all approved screens (sections t2–t4; t1 = early explorations). Open in a browser; pan/zoom canvas.
- `ios-frame.jsx` — device-bezel scaffold used by the HTML (reference only).
- `Personal_Strong_Clone_App_Spec.md` — original functional spec (source of truth for feature completeness; this README overrides it where they differ, e.g. automatic rest days, splits, notifications).

## MVP order (from spec, updated)

1. Exercise database (seed import + custom exercises)
2. Workout logging (grid, set types, rest timer)
3. Templates + folders + favorites
4. Splits + streak logic
5. History
6. Exercise detail (stats, charts, records)
7. Progress dashboard and charts
8. Local notifications
9. CSV export
10. Settings
