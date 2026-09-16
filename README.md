# go/outside

go/outside is a small macOS menu-bar app that compares active computer time today with estimated daylight remaining today. It stores the current day's computer-time total locally and does not use accounts, analytics, a backend, notifications, or an updater.

The app uses Apple's Core Location and geocoding services for the one-shot current-location fix and city lookup. A saved coarse coordinate is enough for offline sunrise and sunset calculations; reverse geocoding only supplies a friendlier label and may use Apple services.

Computer time counts only while go/outside is running. It uses the hardware-input idle timer and stops after 60 seconds without keyboard or mouse input, during sleep or display-off, and while the session is inactive. It does not import historical Screen Time. The circle compares the two durations: solid is computer time divided by computer time plus daylight remaining; hollow is daylight remaining. The numbers beside it show the exact hours and minutes.

The top third of the popover contains only colorful abstract light artwork: flowing color bands, organic blends, and subtle texture. Its brightness, palette, and shape follow the day's light, with subtle variation by date. The comparison below uses evenly spaced black-and-white text over a restrained native glass blur. Both appearances and Reduce Transparency are supported; the gradient is drawn locally without images or an extra service.

Unattended Codex/Claude tasks, CPU work, and terminal output do not count as input. Ordinary software-posted UI events are excluded by the hardware timer. Virtual input devices can still imitate physical input; lock the Mac to stop counting reliably when stepping away. Local tasks can keep running while the Mac remains awake. The initial 60-second idle grace can still count passive reading or the first minute after leaving.

Automatic location uses a one-shot refresh on launch and after wake on a new calendar day or when the last fix is at least six hours old. A failed refresh keeps the saved coordinates and shows a last-known-location state. A manually chosen city stays selected until changed.

## Requirements

- macOS 12 or newer
- Xcode command-line tools, including `swiftc`, `lipo`, `vtool`, `codesign`, and `iconutil`
- An Intel or Apple-silicon Mac, or a macOS SDK that can cross-compile both slices

## Build locally

```sh
cd native
./build.sh
open GoOutside.app
```

The script builds `GoOutside.app` as an arm64/x86_64 universal binary with a macOS 12 deployment target, embeds the macOS 12 login helper, verifies both executable slices, applies an ad-hoc local signature, and runs the deterministic self-tests. Build output is ignored by Git.

An ad-hoc build is intended for local use. macOS may require Control-clicking `GoOutside.app` and choosing **Open**, and Location Services must be allowed in System Settings when using the current-location option. A production build needs its own Developer ID identity, hardened-runtime settings, entitlements review, notarization, and distribution signing. Those steps are separate from this local build and there is no Sparkle or other update service.

The bundle identifier `com.gooutside.desktop` and login-helper identifier `com.gooutside.desktop.login-helper` are development identities for this local fork. Replace them consistently before public distribution and keep the production identity stable afterward.

## Install and launch at login

For a local install, move or copy `GoOutside.app` to `/Applications` and launch it. The app has no Dock icon. Click its menu-bar item to open the comparison; right-click or Control-click for Settings and Quit. While the popover is active, ⌘, opens Settings and ⌘Q quits.

Launch at login is off by default. When enabled, macOS registers the bundled helper at `Contents/Library/LoginItems`; the helper starts the parent with `--login-item` in the background and does not activate the popover. On macOS 13 and newer, System Settings may require approval under **General → Login Items**. macOS 12 has no status-query API for the legacy registration call, so the app reports the last successful request on that OS. A signed, stable bundle identity is required for reliable production login-item registration.

## Source and license

This project is a [GitHub fork](https://github.com/ripe0x/go-outside) and GPL-3.0 derivative of [visualizevalue/ratio](https://github.com/visualizevalue/ratio/tree/682abc1d65f406029faee91c18187ab3fbcd91de), reviewed at commit [`682abc1d65f406029faee91c18187ab3fbcd91de`](https://github.com/visualizevalue/ratio/commit/682abc1d65f406029faee91c18187ab3fbcd91de) on September 16, 2026. The upstream application source and this derivative are licensed under [GNU GPL v3](LICENSE), and the corresponding source and build script are included here.

go/outside uses new fork-owned lowercase branding and a new ratio-circle icon. The Ratio name, Ratio icon, Visualize Value name, and other upstream brand assets are not used or granted by this license. This project does not connect to upstream commercial services.
