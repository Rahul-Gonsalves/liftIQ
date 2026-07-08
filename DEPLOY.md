# DEPLOY.md — Getting liftIQ onto your iPhone

This guide assumes a **free Apple ID** (no $99/yr developer account). One-time
setup is ~30–45 minutes (mostly the Xcode download); after that, refreshing the
app weekly takes about 30 seconds.

## One-time setup

### 1. Install Xcode
- Mac App Store → search **Xcode** → install (~15 GB download, be patient).
- After install, point the command line at it and accept the license:
  ```bash
  sudo xcode-select -s /Applications/Xcode.app
  sudo xcodebuild -license accept
  xcodebuild -runFirstLaunch
  ```

### 2. Generate the Xcode project
The `.xcodeproj` is generated from `project.yml` (it's gitignored — never edit
it directly, edit `project.yml`):
```bash
brew install xcodegen
cd ~/Documents/personal/liftIQ
xcodegen generate
open liftIQ.xcodeproj
```

### 3. Signing (free Apple ID)
1. Xcode → **Settings → Accounts** → `+` → sign in with your Apple ID.
2. Select the **liftIQ** target → **Signing & Capabilities** tab.
3. Check "Automatically manage signing" and pick your **Personal Team**.
4. **Then**: copy the Team ID Xcode shows (looks like `AB12CD34EF`) into
   `project.yml` under `DEVELOPMENT_TEAM:` and commit it. Otherwise the next
   `xcodegen generate` wipes your team selection.

### 4. Prepare the iPhone
1. Plug the phone in with a cable. Tap **Trust** on the phone when prompted.
2. Enable Developer Mode: **Settings → Privacy & Security → Developer Mode**
   → on → phone restarts. (This toggle only appears after Xcode has seen the
   device once — plug in first.)
3. In Xcode's device dropdown (top bar), select your iPhone.

### 5. Run
- Press **⌘R**. First build takes a few minutes.
- First launch will fail with "Untrusted Developer": on the phone go to
  **Settings → General → VPN & Device Management** → tap your Apple ID →
  **Trust**. Run again (or tap the icon).

### 6. Optional: go wireless
Xcode → **Window → Devices and Simulators** → select your phone →
check **Connect via network**. Future re-installs work over Wi-Fi, no cable.

## Living with a free Apple ID — what to expect

**The 7-day rule.** Free-account provisioning profiles expire after 7 days.
When that happens the app icon stays on your phone but tapping it does
nothing. **Your data is NOT gone.** Fix: connect (cable or Wi-Fi), open the
project, ⌘R. Xcode re-signs and reinstalls *in place* — every workout,
template, and streak survives. Make it a weekly habit (e.g. Sunday).

**What actually deletes your data:** only deleting the app from the home
screen, erasing the phone, or a failed restore. Protect yourself:

1. **In-app backup (do this).** Settings → **Back up now (JSON)** → save to
   iCloud Drive (Files app). This one file contains everything — workouts,
   sets, templates, splits, streak, body weight — and Settings → **Restore
   from backup** puts it all back on any install. Home nags you if the last
   backup is >2 weeks old.
2. **Phone backups count too.** iCloud/Finder backups include liftIQ's data
   automatically, restored if you ever restore the whole phone.
3. **CSV export** (Settings) for reading your data in Numbers/Sheets — good
   for analysis, but restore uses the JSON backup, not CSVs.

**Other free-tier limits (all fine for this app):**
- Max 3 sideloaded apps at a time, ~10 new app IDs per week. liftIQ uses one
  fixed bundle ID (`com.rahulgonsalves.liftIQ`) so this never bites.
- No push notifications from servers — irrelevant; all liftIQ notifications
  (rest timer, daily reminder, streak nudge) are local and work fully.
- No iCloud sync entitlements — irrelevant; the app is local-only by design.

**If the weekly re-sign gets annoying:** the $99/yr Apple Developer Program
gives 1-year profiles and TestFlight (90-day installs that you can refresh
from the phone alone). Nothing in the project needs to change.

## Day-2 development notes

- Added/removed Swift files? Run `xcodegen generate` again, then build.
- Model changes (SwiftData schema) during development: delete the app from
  the phone and reinstall (fresh DB + reseed). Back up first if you have data
  you care about — restore-from-backup replays it into the new schema as long
  as the backup format still matches.
- Streak logic self-check (no Xcode needed):
  ```bash
  swiftc -o /tmp/streak_check liftIQ/Services/StreakEngine.swift Tests/main.swift && /tmp/streak_check
  ```
- Rest-timer and reminder notifications only fire on a real device reliably;
  the simulator is flaky with them. Test times by setting reminder/nudge a
  few minutes ahead in the Notifications settings page.
