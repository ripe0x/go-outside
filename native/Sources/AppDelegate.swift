import AppKit
import CoreGraphics
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let todayStore = TodayStore()
    private let locationStore = LocationStore()

    private var tracker: ActivityTracker!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var popoverView: NSView!
    private var glassView: NSVisualEffectView!
    private var statusMenu: NSMenu!
    private var outsideView: OutsideView!
    private var timer: Timer?
    private var screen: OutsideScreen = .main
    private var systemSleeping = false
    private var displaySleeping = false
    private var workspaceSessionActive = true
    private var dictionarySessionActive = false
    private var sessionActive = false
    private var lastPersistedUptime: Double?
    private var lastSolarMinute: Int?
    private var cachedSolar: SolarSnapshot?
    private var lastIconState: RatioState?
    private var lastIconMinute: Int?
    private var lastLocationSignature: String?
    private var settingsError = ""
    private var lastMenuText = ""
    private var isLoginItemLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        isLoginItemLaunch = ProcessInfo.processInfo.arguments.contains("--login-item")
        let now = Date()
        let calendar = Calendar.current
        tracker = ActivityTracker(seconds: todayStore.load(now: now, calendar: calendar), date: now, calendar: calendar)
        updateSessionState()
        lastLocationSignature = locationSignature(locationStore.saved)
        displaySleeping = CGDisplayIsAsleep(CGMainDisplayID()) != 0

        configureStatusItem()
        configurePopover()
        configureNotifications()
        configureLocationUpdates()
        tick()

        timer = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)

        if locationStore.saved == nil {
            screen = .setup
            if !isLoginItemLaunch {
                DispatchQueue.main.async { [weak self] in self?.showPopover() }
            }
        } else if locationStore.saved?.mode == .automatic {
            // This never asks for permission on its own. A denied or unavailable
            // refresh leaves the saved coarse location usable offline.
            locationStore.refresh(userInitiated: false)
        }
        refreshInterface(forceSolar: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        persist()
        timer?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return true
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeft
        button.setAccessibilityRole(.button)
        button.setAccessibilityHelp("Click to compare today's time. Right-click for Settings and Quit.")
        statusMenu = makeStatusMenu()
        let mainMenu = NSMenu()
        let appItem = NSMenuItem(title: "go/outside", action: nil, keyEquivalent: "")
        appItem.submenu = makeStatusMenu()
        mainMenu.addItem(appItem)
        NSApp.mainMenu = mainMenu
    }

    private func makeStatusMenu() -> NSMenu {
        OutsideStatusMenu.make(target: self, settings: #selector(openSettings), quit: #selector(quit))
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 360)
        popoverView = NSView(frame: NSRect(origin: .zero, size: popover.contentSize))
        glassView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 360, height: 240))
        glassView.material = .popover
        glassView.blendingMode = .behindWindow
        glassView.state = .active
        outsideView = OutsideView(frame: popoverView.bounds)
        outsideView.autoresizingMask = [.width, .height]
        outsideView.onBack = { [weak self] in self?.goBack() }
        outsideView.onCurrentLocation = { [weak self] in self?.locationStore.refresh(userInitiated: true) }
        outsideView.onChooseCity = { [weak self] in self?.show(.city) }
        outsideView.onCitySearch = { [weak self] query in self?.locationStore.searchCity(query) }
        outsideView.onCityConfirm = { [weak self] index in
            guard let self, self.locationStore.candidates.indices.contains(index) else { return }
            self.locationStore.chooseCity(self.locationStore.candidates[index])
        }
        outsideView.onLoginChanged = { [weak self] enabled in self?.setLoginLaunch(enabled) }
        popoverView.addSubview(glassView)
        popoverView.addSubview(outsideView)
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = popoverView
    }

    private func configureLocationUpdates() {
        locationStore.onChange = { [weak self] in
            guard let self else { return }
            let signature = self.locationSignature(self.locationStore.saved)
            if signature != self.lastLocationSignature,
               self.locationStore.saved != nil,
               (self.screen == .setup || self.screen == .city) {
                self.screen = .main
            }
            self.lastLocationSignature = signature
            self.refreshInterface(forceSolar: true)
        }
    }

    private func configureNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(screensDidSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(screensDidWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionResigned), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        center.addObserver(self, selector: #selector(sessionBecameActive), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(clockOrTimeZoneChanged), name: .NSSystemClockDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(clockOrTimeZoneChanged), name: .NSSystemTimeZoneDidChange, object: nil)
    }

    @objc private func tick() {
        guard tracker != nil else { return }
        let now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        updateSessionState()
        recordActivity(now: now, uptime: uptime)

        if lastPersistedUptime == nil || uptime - (lastPersistedUptime ?? uptime) >= 10 {
            persist(uptime: uptime, reconcile: false)
        }
        refreshInterface(forceSolar: false)
    }

    private func recordActivity(now: Date = Date(), uptime: Double = ProcessInfo.processInfo.systemUptime) {
        tracker.sample(ActivitySample(
            now: now,
            uptime: uptime,
            // Background tasks and software-posted UI events are not physical
            // computer use. The HID table tracks hardware input independently.
            idleSeconds: CGEventSource.secondsSinceLastEventType(
                .hidSystemState,
                eventType: CGEventType(rawValue: UInt32.max)!
            ),
            systemSleeping: systemSleeping,
            displaySleeping: displaySleeping,
            sessionActive: sessionActive
        ), calendar: Calendar.current)
    }

    @objc private func togglePopover() {
        if OutsideStatusMenu.shouldOpen(for: NSApp.currentEvent),
           let event = NSApp.currentEvent, let button = statusItem.button {
            popover.performClose(nil)
            NSMenu.popUpContextMenu(statusMenu, with: event, for: button)
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    @objc private func openSettings() {
        screen = .settings
        if popover.isShown {
            refreshInterface(forceSolar: true, forceRender: true)
        } else {
            showPopover()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        refreshInterface(forceSolar: true, forceRender: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func show(_ screen: OutsideScreen) {
        self.screen = screen
        refreshInterface(forceSolar: true)
    }

    private func goBack() {
        switch screen {
        case .city:
            show(locationStore.saved == nil ? .setup : .settings)
        case .settings:
            show(locationStore.saved == nil ? .setup : .main)
        case .main, .setup:
            show(locationStore.saved == nil ? .setup : .main)
        }
    }

    @objc private func willSleep() {
        persist()
        systemSleeping = true
        tracker.resetBaseline()
        refreshInterface(forceSolar: true)
    }

    @objc private func didWake() {
        systemSleeping = false
        displaySleeping = CGDisplayIsAsleep(CGMainDisplayID()) != 0
        updateSessionState()
        tracker.resetBaseline()
        locationStore.refreshAfterWake()
        refreshInterface(forceSolar: true)
    }

    @objc private func screensDidSleep() {
        persist()
        displaySleeping = true
        tracker.resetBaseline()
        refreshInterface(forceSolar: true)
    }

    @objc private func screensDidWake() {
        displaySleeping = false
        tracker.resetBaseline()
        refreshInterface(forceSolar: true)
    }

    @objc private func sessionResigned() {
        persist()
        workspaceSessionActive = false
        sessionActive = false
        tracker.resetBaseline()
        refreshInterface(forceSolar: true)
    }

    @objc private func sessionBecameActive() {
        workspaceSessionActive = true
        updateSessionState()
        tracker.resetBaseline()
        refreshInterface(forceSolar: true)
    }

    @objc private func clockOrTimeZoneChanged() {
        tracker.resetBaseline()
        cachedSolar = nil
        lastSolarMinute = nil
        // Sampling immediately makes a clock-induced date change start at zero
        // without treating the jump itself as elapsed computer time.
        tick()
    }

    private func updateSessionState() {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            sessionActive = false
            return
        }
        let onConsole = dictionary[kCGSessionOnConsoleKey as String] as? Bool ?? false
        let loginDone = dictionary[kCGSessionLoginDoneKey as String] as? Bool ?? false
        // Locking does not reliably emit a workspace event. This optional key is
        // supplied by the session dictionary on supported systems; absent means
        // the public on-console/login flags remain the conservative fallback.
        let locked = dictionary["CGSSessionScreenIsLocked"] as? Bool ?? false
        dictionarySessionActive = onConsole && loginDone && !locked
        sessionActive = workspaceSessionActive && dictionarySessionActive
    }

    private func persist(uptime: Double? = nil, reconcile: Bool = true) {
        guard tracker != nil else { return }
        let now = Date()
        if reconcile {
            updateSessionState()
            recordActivity(now: now, uptime: uptime ?? ProcessInfo.processInfo.systemUptime)
        }
        todayStore.save(seconds: tracker.computerSeconds, now: now, calendar: Calendar.current)
        lastPersistedUptime = uptime ?? ProcessInfo.processInfo.systemUptime
    }

    private func refreshInterface(forceSolar: Bool, forceRender: Bool = false) {
        guard tracker != nil, outsideView != nil else { return }
        let now = Date()
        let calendar = Calendar.current
        let minute = Int(now.timeIntervalSinceReferenceDate / 60)
        let crossedSolarBoundary = cachedSolar.map { snapshot in
            switch snapshot.state {
            case .beforeSunrise:
                return snapshot.nextSunrise.map { $0 <= now } ?? false
            case .daylight:
                return snapshot.nextSunset.map { $0 <= now } ?? false
            case .afterSunset, .polarDay, .polarNight:
                return false
            }
        } ?? false
        if forceSolar || minute != lastSolarMinute || crossedSolarBoundary || popover.isShown {
            cachedSolar = locationStore.saved.map {
                SolarCalculator.snapshot(at: now, latitude: $0.latitude, longitude: $0.longitude, calendar: calendar)
            }
            lastSolarMinute = minute
        }

        let model = OutsideModel(
            computer: tracker.computerSeconds,
            solar: cachedSolar,
            locationName: locationStore.saved?.name ?? "Location needed",
            isLastKnown: locationStore.isLastKnown,
            isAway: tracker.isAway,
            now: now
        )
        if forceRender || popover.isShown {
            outsideView.render(
                model: model,
                screen: screen,
                locationMessage: settingsError.isEmpty ? locationStore.message : settingsError,
                isRequesting: locationStore.isRequesting,
                candidates: locationStore.candidates,
                loginEnabled: LoginLaunch.isEnabled
            )
            popover.contentSize = outsideView.preferredSize
            popoverView.setFrameSize(outsideView.preferredSize)
            outsideView.frame = popoverView.bounds
            glassView.frame = outsideView.contentBounds
            glassView.isHidden = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
        updateStatus(with: model, minute: minute, forceIcon: forceSolar || crossedSolarBoundary)
    }

    private func updateStatus(with model: OutsideModel, minute: Int, forceIcon: Bool) {
        guard let button = statusItem.button else { return }
        if model.menuText != lastMenuText {
            button.title = model.menuText
            lastMenuText = model.menuText
        }
        let iconState = model.ratio
        if iconState != lastIconState && (forceIcon || lastIconMinute != minute || ratioKindChanged(from: lastIconState, to: iconState)) {
            button.image = RatioIcon.image(for: iconState)
            lastIconState = iconState
            lastIconMinute = minute
        }
        button.toolTip = "\(model.computerText) on your computer today. \(model.daylightText) of daylight remaining."
        button.setAccessibilityLabel(model.accessibility)
    }

    private func ratioKindChanged(from old: RatioState?, to new: RatioState) -> Bool {
        guard let old else { return true }
        if case .share = old, case .share = new { return false }
        return true
    }

    private func locationSignature(_ location: SavedLocation?) -> String? {
        guard let location else { return nil }
        return "\(location.latitude),\(location.longitude),\(location.updatedAt.timeIntervalSinceReferenceDate),\(location.mode.rawValue)"
    }

    private func setLoginLaunch(_ enabled: Bool) {
        do {
            try LoginLaunch.setEnabled(enabled)
            settingsError = ""
            refreshInterface(forceSolar: false, forceRender: true)
        } catch {
            settingsError = error.localizedDescription
            refreshInterface(forceSolar: false, forceRender: true)
        }
    }
}
