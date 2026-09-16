# go/outside

A tiny macOS menu-bar app that compares active computer time today with daylight remaining today.

**The question:** “How much of today have I spent here, and how much daylight can I still catch?”

Status: v1 implemented in the [GitHub fork](https://github.com/ripe0x/go-outside) on its default `go-outside` branch, with a universal `native/GoOutside.app` build. Accounting, solar, atmosphere, location-policy, presentation, and native-control self-tests pass; light/dark layouts and the 20-point ratio icon have been visually checked. The app has been launched locally and the current-location comparison works. Developer ID signing and notarized distribution remain separate work.

## Review of Ratio

Reviewed [visualizevalue/ratio](https://github.com/visualizevalue/ratio/tree/682abc1d65f406029faee91c18187ab3fbcd91de), commit `682abc1d65f406029faee91c18187ab3fbcd91de`, on September 16, 2026. Review covered the source, bundle configuration, build scripts, README, and update documentation. The upstream app was not built or run.

The repository is a small native Swift/AppKit app, not a website. Its application lives in one 1,170-line file. Its build targets macOS 12+ on Intel and Apple silicon. It already provides a menu-bar item, transient popover, monospaced typography, grid borders, idle detection, session/sleep handling, and local storage.

Its accounting model attributes foreground app/site usage to create/consume categories. That model is unnecessary here: every eligible second should count regardless of which app is open. Its browser AppleScript, classification UI, history, purchaser authentication, Sparkle updates, and anonymous reporting can all go.

An important detail in the current source: `render()` and `refreshApps()` force the selected tab to zero; `refreshApps()` hides the large ratio and displays the activity/review or history list. Reuse the visual primitives, but build a fresh comparison view rather than assuming the existing ratio screen is the current working layout.

Useful upstream anchors:

- [Fonts, colors, and grid buttons](https://github.com/visualizevalue/ratio/blob/682abc1d65f406029faee91c18187ab3fbcd91de/native/Sources/main.swift#L75).
- [Popover and interface layout](https://github.com/visualizevalue/ratio/blob/682abc1d65f406029faee91c18187ab3fbcd91de/native/Sources/main.swift#L298).
- [Menu-bar setup and lifecycle observers](https://github.com/visualizevalue/ratio/blob/682abc1d65f406029faee91c18187ab3fbcd91de/native/Sources/main.swift#L818).
- [One-second accounting loop](https://github.com/visualizevalue/ratio/blob/682abc1d65f406029faee91c18187ab3fbcd91de/native/Sources/main.swift#L881).
- [Build script](https://github.com/visualizevalue/ratio/blob/682abc1d65f406029faee91c18187ab3fbcd91de/native/build.sh).

## Product boundaries

Keep v1 to one comparison, one location setup, and a small settings sheet.

- Native Mac menu-bar app; no Dock icon or main dashboard.
- Computer time means active use of this Mac while go/outside is running. It includes work, browsing, games, and interaction with go/outside itself.
- Daylight means estimated sunrise-to-sunset daylight still available in today's Mac calendar day, at the selected location. It excludes twilight.
- This does not measure time outdoors, total time indoors, phone use, or usage on other computers.
- No Screen Time import or reconstruction of use before installation, launch, or while the app is closed. Explain this on first launch and in the computer-time tooltip.
- No accounts, server, analytics, notifications, goals, streaks, rankings, per-app reports, historical charts, or website.

## Main interface

Keep Ratio's sparse comparison and compact popover. Use black, white, and neutral greys for UI elements only, following system light/dark appearance. Keep color in the artwork above them. Use clear system labels, condensed tabular clock numerals, consistent 24-point margins, and equal left-aligned comparison columns.

The top third of each popover contains only original colorful abstract light artwork, with no title, labels, buttons, or glass card over it. Use an airy, vibrant gradient with two related hues, gentle distortion, a broad bright area, and restrained fine grain. Create original artwork locally. Brightness, palette, and shape evolve through dawn, noon, sunset, and night using the calculated solar phase; keep the composition simple and fully inside the artwork region. Move the main bright area monotonically from left to right between sunrise and sunset, distorting the surrounding color field; avoid rings and isolated objects. Add a subtle deterministic daily variation in the shape. Without location, use a cosmetic wall-clock progression while daylight stays unknown.

Place all information and essential setup controls in the lower two-thirds. Native AppKit visual-effect material supplies a very subtle blur behind this region only; a near-opaque neutral tint keeps text contrast stable against the desktop. Use opaque grayscale text with strong contrast in both appearances. Reduce Transparency makes the information region opaque while preserving the decorative gradient. Update through the existing open-popover refresh, with no continuous animation loop or redraw of closed UI.

The brand is **go/outside**, in lowercase. Use a new ratio-circle icon drawn with native paths. Do not reuse Ratio's logo or Visualize Value branding.

### Menu bar

```text
◕ 4h12 / 2h08
```

Left always means computer time; right always means daylight left. The tooltip spells out both meanings. Selected icon: a ratio circle, with a solid sector for active computer time today and a hollow sector for daylight remaining today. The text symbol above is schematic; draw the actual sector accurately with native paths.

Let `S` be computer seconds and `D` be daylight seconds. The solid share is `S / (S + D)` and the hollow share is `D / (S + D)`. Start the solid sector at 12 o'clock and expand clockwise. For 4 hours of computer use and 2 hours of daylight left, the circle is two-thirds filled. This is a comparison of the two quantities, not a partition of the day's hours or a measure of time outdoors. It communicates their balance; the durations communicate their absolute size.

Render as a monochrome template image for both appearances, with a fixed 20 × 20-point footprint, thin circular outline, and no sun, moon, or continuous animation. Update once per minute and immediately on sunrise/sunset, wake, date rollover, or location changes. The circle generally fills as computer use accumulates and daylight decreases; location changes and daily resets can change that direction. Validate legibility at actual menu-bar size.

Zero and unknown cases:

- `S = 0, D > 0`: hollow circle.
- `S > 0, D = 0`: fully solid circle, including after sunset or on a polar-night day. This means no daylight remains, not that the whole day was spent on the computer.
- `S = 0, D = 0`: hollow circle with a small central dash; no ratio exists.
- Missing location: circle with a question mark; show `—` for daylight and do not compute a ratio.
- Before sunrise and during polar day, use the same `S / (S + D)` calculation with the daylight rules below. Do not substitute a full daylight ring.

The menu-bar tooltip and VoiceOver label identify both durations. Remove the solid/hollow legend from the interface and accessibility copy; retain the ratio-circle calculation.

### Popover

The main comparison is 360 × 360 points: a 120-point gradient section above a 240-point information section. Setup, settings, and the city fallback may be taller to accommodate their essential controls, retaining the same one-third/two-thirds division with no tabs or scrolling.

Below the gradient, show `go/outside` and `TODAY` or `AWAY` on one header baseline. Left-align the two condensed clocks in equal columns, with sentence-case labels underneath. Place the sunrise/sunset context and state message below them, with consistent margins and vertical spacing. Tune against `23:59:59 / 23:59:59` so long values fit. The slash compares durations; it is not a percentage or a productivity score.

Remove Settings and Quit buttons from the popover. Right-click or Control-click the menu-bar item for a native menu with Settings and Quit. Left-click continues to toggle the comparison. While the app is active, ⌘, opens Settings and ⌘Q quits. Keep Back on auxiliary screens and retain necessary location, city-search, and login controls.

Keep the ratio circle in the menu bar and the labeled durations in the popover. Do not add a second chart, progress bar, or daily percentage score.

State copy, evaluated in this order:

1. Missing location: `Allow location to find your daylight.` Offer the city fallback. Show computer time and `—` for daylight, never a fabricated estimate.
2. Polar night: `No daylight today. Tomorrow is another day.`
3. Polar day: `Daylight all day. Go catch some.` Show daylight remaining until local midnight, and omit a nonexistent sunset.
4. Before sunrise: `The sun's not up yet.` Replace the sunset context with estimated sunrise time.
5. After sunset: `The sun clocked out. You can too.` Keep counting computer use; daylight remains `0m`.
6. During daylight, with 60 minutes or less left: `Last light. Go/outside?`
7. Other daytime: `Still time to go/outside.`

An `AWAY` label beside TODAY appears during idle, screen-off, sleep, or inactive-session states. The saved computer duration stays visible and daylight continues to follow wall-clock time. No punitive red states, modal nags, or push notifications.

## Location and settings

On first launch, start computer accounting immediately and show one location setup inside the popover:

- Primary: **Use current location**. Explain `Your location is used to estimate sunrise and sunset`, then let the click trigger the macOS location permission flow. Get one fix and stop updates. No initial city search is needed. Once authorized, future refreshes need no repeated in-app confirmation.
- Fallback: **Choose a city**, shown if access is denied, unavailable, or the user prefers a manual location. Resolve a typed city through Apple's geocoding service; disambiguate matches with region/country before saving.
- Save city label and coordinates rounded to 0.01 degrees. Precise location and ongoing travel history are unnecessary.
- A location lookup can require network access. Once saved, sunset calculation and tracking work offline. If lookup fails, show a retry message; leave daylight unknown until setup succeeds.
- In automatic mode, refresh with a one-shot fix on launch, at the first wake of a new calendar day, or after wake if the last fix is at least 6 hours old. Settings offers **Refresh location** for travel. No continuous location monitoring. In manual-city mode, keep that city until changed.
- Cache the last successful coarse fix and timestamp. If automatic refresh fails, keep using the saved coordinates offline and label the location `Last known location`; offer retry. If permission is revoked, stop refreshing and offer the city fallback. A reverse-geocoding failure must not block solar calculations from a valid fix; show `Current location` instead of a city name.

Settings has only **Location** and **Launch at login**, plus a short tracking explanation. Launch at login defaults off; offer it during setup to make future daily totals more complete. Support macOS 12 with a compatible login helper rather than silently requiring macOS 13 APIs. If a helper is used, its launch path must start tracking without reopening setup or activating the popover once location is configured.

Remove Pause and Reset from the main interface. Automatic away detection handles breaks; Quit stops tracking. Do not invite users to erase the comparison to improve a score.

## Accounting rules

### Computer time

Maintain one `computerSeconds` total for the current Mac calendar date.

- Sample hardware activity every second using the public CoreGraphics idle-age query with `.hidSystemState`, rather than the combined session table. Do not record key contents, mouse positions, app names, window titles, or websites.
- Stop counting after **60 seconds without input**. The initial idle grace period can count up to 60 seconds of passive reading or inactivity. Video playback without input stops counting after that cutoff too; this is an active-use estimate.
- Background CPU/network tasks and terminal output do not reset hardware idle. Ordinary software-posted UI events are excluded; virtual HID devices can still imitate physical input. Locking the Mac is the reliable way to stop counting during unattended work, which can continue while the Mac stays awake.
- Stop on system sleep, display sleep, or session resignation. Track these as separate flags so waking a display cannot incorrectly resume an inactive session.
- Resume only when the session and display are active and the idle age is below 60 seconds. Do not charge the interval spanning an away-to-active transition.
- Use a monotonic clock for elapsed accounting, independent of clock adjustments. Retain upstream's conservative guard: accept only tick intervals greater than zero and at most **3 seconds**. Longer suspension gaps are not backfilled.
- Split an accepted interval crossing midnight at the calendar boundary, then retain only the new day's share. Do not assume every day lasts 86,400 seconds.
- Persist every **10 seconds**, and on quit, sleep, and session resignation. A crash can lose up to 10 seconds. Relaunch restores today's persisted total and never counts closed-app time.
- On a date change, discard the previous day's total. No daily history is retained.
- On timezone or manual clock changes, re-evaluate the day and solar state, reset the sampling baseline, and never add a clock jump. If the calendar date changes, start a fresh total for that date. Document that travel may reset today's count.

### Daylight left

Let `S` be today's active computer seconds and `D` be remaining daylight seconds.

For an ordinary local sunrise/sunset pair:

```text
before sunrise:  D = sunset − sunrise
during daylight: D = sunset − now
after sunset:    D = 0
```

Before sunrise, the number represents the daylight still coming today, not darkness plus daylight until sunset.

Implementation definition: sum daylight intervals intersecting `[now, next Mac-local midnight)`. Compute neighboring solar dates as necessary so locations far from the Mac's timezone work too. All visible sunrise/sunset clock times use the Mac's timezone. Daylight and computer time share that same calendar-day boundary.

Use a small pure Swift sunrise/sunset calculation locally, based on documented solar equations, with the conventional **90.833° zenith**. Return explicit normal-day, polar-day, and polar-night states; a missing crossing alone must not imply darkness. [NOAA's calculation notes](https://gml.noaa.gov/grad/solcalc/calcdetails.html) document the underlying Meeus equations and approximation limits; their web calculator is no longer maintained, so it should not be a runtime dependency.

Sunset is an estimate, not a promise of visible sun. Weather, buildings, terrain, refraction, and high latitude affect actual light. Use `~` beside sunrise/sunset and a tooltip explaining this. No weather API is needed.

Recalculate solar intervals on launch, location change, calendar-date/timezone change, and wake. Derive the remaining duration from the current time on each tick instead of decrementing a saved countdown.

### Formatting

- Store seconds; show the main count-up and countdown clocks as `H:MM:SS`.
- Computer time rounds down to completed seconds. Daylight rounds up to the next second while positive, so it never displays zero before daylight actually ends.
- Examples: `0:00:00`, `0:08:23`, `1:03:07`, `4:12:59`.
- A missing location uses `—`; zero available daylight uses `0:00:00`.
- The compact menu title retains minute precision (`8m`, `1h03`), rounding computer time down and positive daylight up.
- Refresh the menu title only when its displayed minute or state changes. Update the open popover as needed; avoid redrawing closed UI every second.
- VoiceOver reads a full sentence: `Four hours twelve minutes five seconds on your computer today. Two hours eight minutes seven seconds of daylight remaining.` All controls support keyboard navigation; Escape closes the popover.

## Fork implementation

Keep Swift/AppKit, macOS 12+, a universal binary, and GPL-3.0. No SwiftUI migration or external runtime package is necessary.

Use a few small files instead of preserving the monolith:

```text
native/
  Sources/
    main.swift             # App entry and launch modes
    AppDelegate.swift      # Status item, popover, lifecycle
    ActivityTracker.swift  # Activity eligibility and elapsed accounting
    SolarCalculator.swift  # Pure solar intervals and daylight states
    LocationStore.swift    # Primary one-shot location, city fallback
    TodayStore.swift       # Today's total and preferences
    OutsideView.swift      # Glass comparison, setup, settings
    DaylightAtmosphere.swift # Local distorted gradient and moving daylight
  Tests/
    AccountingTests.swift
    SolarTests.swift
    AtmosphereTests.swift
  Resources/
    Info.plist
    GoOutside.icns
  build.sh
LICENSE
README.md
```

If needed for macOS 12 login support, add a minimal helper target and bundle it under `Contents/Library/LoginItems`. Otherwise keep the native build as small as possible.

Reuse the status-item/popover lifecycle and ratio-circle drawing patterns. Replace `AppUsage`, classified `Ledger`, `DaySummary`, and `ResetSnapshot` with a dated scalar total. Keep separate UserDefaults storage under a new bundle identifier, so installation can coexist with Ratio and never reads or overwrites its data.

Remove:

- Classification rules, built-in app/site lists, pending review, per-app identity, foreground-app attribution, and browser polling/AppleScript.
- Ratio/Apps tabs, create/consume buttons, app and review lists, history list, reset/undo, pause controls, and manual appearance control.
- `UpdateCredential`, sign-in/code input, Security/Keychain code, purchaser endpoints, anonymous telemetry, and all related defaults.
- Sparkle imports/framework/resources, `setup-sparkle.sh`, vendor setup, updater options, original appcast URL/public key, and `UPDATES.md`.
- Browser automation usage description and Apple Events entitlement. Add the appropriate macOS location usage description for the primary location feature. Validate location authorization and activity detection on clean installs without adding event taps or requesting unnecessary permissions.
- Upstream app bundle and icons; generate a clean `GoOutside.app` from fork-owned resources.

Display name: `go/outside`. Filesystem bundle: `GoOutside.app`, because `/` cannot be used inside a filename. Choose a fork-owned bundle identifier before distribution; never retain `com.visualizevalue.ratio.prototype`.

Build with system frameworks only: AppKit, CoreGraphics, and CoreLocation, plus any system framework needed by the login helper. Preserve both architecture slices, deployment-target checks, ad-hoc local signing, and self-tests. No updater or service setup should be required to compile.

The repository explicitly licenses application source under GPL-3.0 and excludes the Ratio name/icon and Visualize Value brand assets. Preserve the license and upstream attribution; distributed derivative builds must meet the GPL's corresponding-source requirements. Use new branding and do not connect to upstream commercial services. See the [upstream license statement](https://github.com/visualizevalue/ratio/blob/682abc1d65f406029faee91c18187ab3fbcd91de/README.md#license).

## Implementation sequence

1. Create the local derivative from the reviewed commit; retain attribution and license. Strip commercial integrations and change bundle identity/resources until it builds without Sparkle.
2. Replace categorized tracking with a scalar today ledger. Verify activity, overlapping away states, relaunch, midnight, and clock changes.
3. Add solar calculations and location setup. Verify ordinary, before-sunrise, after-sunset, timezone-offset, and polar cases with fixed dates.
4. Build the single comparison view, state copy, appearance, keyboard/VoiceOver labels, and optional login launch.
5. Run the acceptance checks, create a locally signed universal app, and document install/build steps. Public signing, notarization, and automatic updates are separate distribution work.

## Acceptance checks

- Two minutes of eligible simulated use adds 120 seconds, regardless of app or site. Test with injected clocks/activity rather than waiting in real time.
- One hour of an awake, active session without hardware input adds only the initial 60-second grace, then remains away. No input for 60 seconds stops additional accumulation. Input resumes counting without charging the preceding away interval.
- Sleep, display-off, and inactive-session combinations never count, even if wake notifications arrive in a different order. A gap over 3 seconds and a wall-clock jump never inflate totals.
- A same-day restart restores persisted time; time while closed is excluded. Midnight clears yesterday and preserves the accepted interval after midnight. Test 23-hour and 25-hour calendar days.
- With synthetic sunrise at 7:00 AM and sunset at 7:00 PM: 6:00 AM shows 12h daylight, noon shows 7h, and 8:00 PM shows 0m.
- Solar fixtures for equatorial and mid-latitude locations agree with an independent reference within 2 minutes. Include dates around DST and polar fixtures with no crossings; avoid live network tests.
- A selected location in a different timezone still produces the correct daylight intervals within the Mac's current calendar day. Polar day shows the actual duration until midnight; polar night shows zero.
- Granted location access produces daylight without a city-search step. Denied location access and failed city lookup keep tracking usable and daylight unknown when no saved coordinates exist. With a saved fix or city, offline launch shows daylight; failed automatic refresh exposes the last-known-location state. Verify one-shot refresh timing and that manual-city mode never starts location updates.
- Unknown and zero daylight are visually distinct. Positive daylight never rounds to zero early. Long durations fit in the menu bar and popover in both appearances.
- The ratio circle is two-thirds solid for `S = 4h, D = 2h`, hollow for `S = 0, D > 0`, and solid for `S > 0, D = 0`. Both-zero and missing-location states avoid division by zero and remain distinguishable. Check actual 20-point rendering, light/dark appearance, and the accessible duration labels.
- Dawn, noon, sunset, and night previews show changing colored light, brightness, and organic shape in the top third, with no content overlapping it in either appearance. The same date and time yield the same background, adjacent dates vary subtly, and polar/unknown states remain finite and readable. All controls fit below the gradient; Settings and Quit work through the native context menu. Reduce Transparency retains an opaque, readable surface.
- Settings, city selection, and quitting work with keyboard and VoiceOver. Login launch starts in the background after setup on both macOS 12 and a current macOS version.
- Built binary includes Intel and Apple silicon slices with the advertised macOS 12 deployment target. Fork resources/configuration contain no upstream updater endpoint, purchaser flow, telemetry, Apple Events capability, or original branding.

**Done means:** one quiet menu-bar comparison, accurate enough to be useful, with no categorization chores. Open it, see what you've spent and what sunlight remains, then decide to go/outside.
