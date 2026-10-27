import AppKit
import Carbon
import Combine
import SwiftUI
import StilldayCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var popover: NSPopover?
    private var store: AppState!
    private var youtube: YouTubeController?
    private let navigation = SettingsNavigation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let benchmark = ProcessInfo.processInfo.arguments.contains("--benchmark-navigation")
        let interactivePreview = ProcessInfo.processInfo.arguments.contains("--preview-controls")
        let diagnostic = ProcessInfo.processInfo.arguments.contains("--smoke-test") || benchmark || interactivePreview
        let settings = ProcessInfo.processInfo.environment["STILLDAY_TEST_SETTINGS"].map { URL(fileURLWithPath: $0) }
        store = AppState(diagnosticMode: diagnostic, settingsOverride: diagnostic ? settings : nil)
        installAppMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "StilldayControls"
        item.behavior = []
        item.isVisible = true
        let icon = NSImage(systemSymbolName: "sun.horizon.fill", accessibilityDescription: "Stillday")
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        item.button?.image = icon
        item.button?.setAccessibilityLabel("Stillday quick controls")
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        store.onChange = { [weak self] in self?.refreshMenu() }
        store.onYouTubeRequested = { [weak self] id in
            guard let self else { return }
            if self.youtube == nil {
                self.youtube = YouTubeController()
                self.youtube?.onClose = { [weak self] in
                    self?.youtube = nil
                    self?.store.youtubeWindowClosed()
                }
                self.youtube?.onStatus = { [weak self] playing, message in self?.store.youtubePlaybackChanged(playing: playing, message: message) }
            }
            self.youtube?.show(videoID: id, volume: self.store.preferences.volume)
        }
        store.onYouTubeStopped = { [weak self] in self?.youtube?.stop(); self?.youtube = nil }
        store.onVolumeChanged = { [weak self] value in self?.youtube?.setVolume(value) }
        store.start()
        refreshMenu()
        if benchmark {
            navigation.page = "general"
            showSettings()
            Task {
                await NavigationBenchmark.run(store: store, navigation: navigation)
                store.shutdown(); window?.close(); NSApp.terminate(nil)
            }
            return
        }
        if interactivePreview { showSettings(); return }
        if diagnostic { runSmokeTest(); return }
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunched")
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let launchAtLogin = launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
            || ProcessInfo.processInfo.arguments.contains("--background")
        if !hasLaunched || !launchAtLogin { showSettings() }
        UserDefaults.standard.set(true, forKey: "hasLaunched")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusItem?.isVisible = true
        showSettings()
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { store?.shutdown() }

    private func installAppMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Stillday", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(withTitle: "Settings…", action: #selector(showPreferences), keyEquivalent: ",")
        let controls = appMenu.addItem(withTitle: "Quick Controls", action: #selector(showControls), keyEquivalent: " ")
        controls.keyEquivalentModifierMask = [.command, .shift]
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Stillday", action: #selector(quit), keyEquivalent: "q")
        for item in appMenu.items where !item.isSeparatorItem { item.target = self }
        appItem.submenu = appMenu; menu.addItem(appItem)
        let edit = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        for (title, action, key) in [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] {
            editMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
        }
        edit.submenu = editMenu; menu.addItem(edit)
        let windowMenu = NSMenu(title: "Window")
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        let minimize = windowMenu.addItem(withTitle: "Minimize Window", action: #selector(minimizeCurrentWindow), keyEquivalent: "w")
        minimize.target = self
        windowItem.submenu = windowMenu; menu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = menu
    }

    private func refreshMenu() {
        guard let store else { return }
        NSApp.appearance = store.preferences.appearance.nativeAppearance
        statusItem?.button?.appearsDisabled = !store.preferences.enabled
        statusItem?.button?.toolTip = "Stillday · \(store.activePhase?.name ?? "Your day")"
    }

    @objc private func togglePopover() {
        if popover?.isShown == true { popover?.performClose(nil); return }
        DispatchQueue.main.async { [weak self] in self?.showPopover() }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        let panel = NSPopover()
        panel.behavior = .transient
        panel.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.delegate = self
        let controller = NSHostingController(rootView: MenuBarView(store: store,
            openSettings: { [weak self] in self?.popover?.performClose(nil); self?.showPreferences() },
            openYouTube: { [weak self] in self?.youtube?.showExisting() },
            quit: { NSApp.terminate(nil) }))
        controller.sizingOptions = [.preferredContentSize]
        panel.contentViewController = controller
        panel.contentSize = NSSize(width: 360, height: 700)
        popover = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        controller.view.window?.title = "Stillday Controls"
        controller.view.window?.makeKeyAndOrderFront(nil)
        if ProcessInfo.processInfo.arguments.contains("--preview-controls") {
            NSLog("Stillday popover shown=%@ size=%@ anchor=%@", String(panel.isShown), NSStringFromSize(panel.contentSize), NSStringFromRect(button.window?.frame ?? .zero))
        }
    }

    func popoverDidClose(_ notification: Notification) {
        popover?.contentViewController = nil
        popover = nil
        if window == nil { ImageCache.shared.clear() }
    }

    @objc func showSettings() {
        NSApp.setActivationPolicy(.regular)
        if let window { window.deminiaturize(nil); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Stillday"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 960, height: 700)
        window.contentView = NSHostingView(rootView: SettingsView(store: store, navigation: navigation, openYouTube: { [weak self] in self?.youtube?.showExisting() }))
        window.delegate = self
        window.isReleasedWhenClosed = false
        if !window.setFrameUsingName("StilldaySettings") { window.center() }
        window.setFrameAutosaveName("StilldaySettings")
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showControls() { navigation.page = "controls"; showSettings() }
    @objc private func showPreferences() { navigation.page = "general"; showSettings() }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow, closed === window else { return }
        closed.contentView = nil
        window = nil
        NSApp.setActivationPolicy(.accessory)
        if popover?.isShown != true { ImageCache.shared.clear() }
    }

    @objc private func minimizeCurrentWindow() {
        if popover?.isShown == true { popover?.performClose(nil); return }
        (NSApp.keyWindow ?? window)?.performMiniaturize(nil)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--preview-controls"), let window = notification.object as? NSWindow {
            NSLog("Stillday window minimized=%@", String(window.isMiniaturized))
        }
    }

    @objc private func showAbout() { NSApp.orderFrontStandardAboutPanel(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func runSmokeTest() {
        showSettings()
        let fixture = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--audio-fixture=") }).map { String($0.dropFirst("--audio-fixture=".count)) }
        let youtubeFixture = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--youtube-fixture=") }).map { String($0.dropFirst("--youtube-fixture=".count)) }
        if let youtubeFixture {
            store.update { settings in
                settings.wallpaperEnabled = false; settings.enabled = true; settings.audioEnabled = true; settings.volume = 0
                for index in settings.phases.indices { settings.phases[index].youtubeURL = youtubeFixture; settings.phases[index].audioSource = .youtubeAudio }
            }
        } else if let fixture {
            store.update { settings in
                settings.wallpaperEnabled = false; settings.enabled = true; settings.audioEnabled = true; settings.volume = 0
                for index in settings.phases.indices { settings.phases[index].audioPath = fixture; settings.phases[index].audioSource = .local }
            }
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let playbackDeadline = ContinuousClock.now.advanced(by: .seconds(youtubeFixture == nil ? 5 : 70))
            while (!self.store.audioPlaying || self.store.audioPlaybackSeconds < 0.25), self.store.error == nil, ContinuousClock.now < playbackDeadline { try? await Task.sleep(for: .milliseconds(100)) }
            let audioConnectionFailed = self.store.error != nil
            let settingsInAppSwitcher = NSApp.activationPolicy() == .regular
            let audioWasPlaying = self.store.audioPlaying && self.store.audioPlaybackSeconds >= 0.25
            let audioLibraryChecks = if let fixture { await AudioLibraryChecks.run(store: self.store, fixture: fixture) } else { [String: Bool]() }
            let checksRepeat = ProcessInfo.processInfo.arguments.contains("--check-stream-repeat")
            var streamRepeated = !checksRepeat
            if checksRepeat, audioWasPlaying {
                let repeatDeadline = ContinuousClock.now.advanced(by: .seconds(45))
                var previous = self.store.audioPlaybackSeconds
                var restarted = false
                while ContinuousClock.now < repeatDeadline, self.store.error == nil {
                    try? await Task.sleep(for: .milliseconds(100))
                    let current = self.store.audioPlaybackSeconds
                    if current < previous - 0.5 { restarted = true }
                    if restarted, self.store.audioPlaying, current > 0.25 { streamRepeated = true; break }
                    previous = current
                }
            }
            let expectedEnabled = self.store.preferences.enabled
            self.store.update { settings in settings.phases[1].startMinute = settings.phases[0].startMinute }
            let duplicateRejected = self.store.error != nil && Set(self.store.preferences.phases.map(\.startMinute)).count == self.store.preferences.phases.count
            let thumbnailLoaded = if let path = self.store.library.first {
                await ImageCache.shared.image(path: path, pixels: 380) != nil
            } else { true }
            self.minimizeCurrentWindow()
            let minimizeDeadline = ContinuousClock.now.advanced(by: .seconds(2))
            while self.window?.isMiniaturized != true, ContinuousClock.now < minimizeDeadline { try? await Task.sleep(for: .milliseconds(20)) }
            let minimized = self.window?.isMiniaturized == true
            let minimizedTime = self.store.audioPlaybackSeconds
            try? await Task.sleep(for: .milliseconds(350))
            let backgroundAudioWhileMinimized = self.store.audioPlaying && abs(self.store.audioPlaybackSeconds - minimizedTime) > 0.05
            let minimizedInAppSwitcher = NSApp.activationPolicy() == .regular
            self.showSettings()
            let restoreDeadline = ContinuousClock.now.advanced(by: .seconds(2))
            while self.window?.isMiniaturized == true, ContinuousClock.now < restoreDeadline { try? await Task.sleep(for: .milliseconds(20)) }
            self.window?.close()
            let closedTime = self.store.audioPlaybackSeconds
            try? await Task.sleep(for: .milliseconds(350))
            let backgroundAudioWhileClosed = self.store.audioPlaying && abs(self.store.audioPlaybackSeconds - closedTime) > 0.05
            let menuBarOnlyWhenClosed = NSApp.activationPolicy() == .accessory
            self.showSettings()
            self.store.update { $0.enabled = false }
            // Stop a real pending extraction before it can replace the paused source.
            self.store.update { settings in
                for index in settings.phases.indices {
                    settings.phases[index].audioSource = .youtubeAudio
                    settings.phases[index].youtubeURL = "https://youtu.be/BaW_jenozKc"
                }
                settings.audioEnabled = true; settings.enabled = true
            }
            try? await Task.sleep(for: .milliseconds(300))
            let extractionWasPending = self.store.audioStatus == "Connecting to YouTube audio…"
            self.store.update { $0.enabled = false }
            try? await Task.sleep(for: .milliseconds(500))
            let pendingAudioCancelled = !self.store.audioPlaying && self.store.audioStatus == "Ambient sound is off"
            let menuBarVisibilityRequested = self.statusItem?.isVisible == true
            self.statusItem?.isVisible = false
            _ = self.applicationShouldHandleReopen(NSApp, hasVisibleWindows: true)
            let menuDeadline = ContinuousClock.now.advanced(by: .seconds(2))
            while self.statusItem?.button?.window == nil, ContinuousClock.now < menuDeadline { try? await Task.sleep(for: .milliseconds(20)) }
            let anchor = self.statusItem?.button?.window?.frame ?? .zero
            let menuBarAnchorNearTop = anchor.width > 0 && NSScreen.screens.contains { screen in
                anchor.minX >= screen.frame.minX && anchor.maxX <= screen.frame.maxX
                    && abs(anchor.maxY - screen.frame.maxY) < 2
                    && anchor.height >= NSStatusBar.system.thickness - 2
            }
            self.statusItem?.button?.performClick(nil)
            let panelDeadline = ContinuousClock.now.advanced(by: .seconds(2))
            while self.popover?.isShown != true, ContinuousClock.now < panelDeadline { try? await Task.sleep(for: .milliseconds(20)) }
            let quickControlsOpened = self.popover?.isShown == true
            self.popover?.performClose(nil)
            var report: [String: Any] = [
                "libraryCount": self.store.library.count,
                "phaseCount": self.store.preferences.phases.count,
                "activePhase": self.store.activePhase?.name ?? "none",
                "firstThumbnailLoaded": thumbnailLoaded,
                "settingsWindowVisible": self.window?.isVisible == true,
                "desktopEffectsSuppressed": self.store.diagnosticMode,
                "localAudioStarted": fixture == nil || audioWasPlaying,
                "youtubeAudioStarted": youtubeFixture == nil || audioWasPlaying,
                "youtubeFixtureProvided": youtubeFixture != nil,
                "repeatCheckProvided": checksRepeat,
                "streamRepeated": streamRepeated,
                "backgroundAudioWhileMinimized": (fixture == nil && youtubeFixture == nil) || backgroundAudioWhileMinimized,
                "backgroundAudioWhileClosed": (fixture == nil && youtubeFixture == nil) || backgroundAudioWhileClosed,
                "settingsInAppSwitcher": settingsInAppSwitcher,
                "minimizedInAppSwitcher": minimizedInAppSwitcher,
                "menuBarOnlyWhenClosed": menuBarOnlyWhenClosed,
                "pendingExtractionStarted": extractionWasPending,
                "pendingAudioCancelled": pendingAudioCancelled,
                "audioConnectionFailed": audioConnectionFailed,
                "audioFixtureProvided": fixture != nil,
                "duplicateTimeRejected": duplicateRejected,
                "masterPauseStoppedAudio": !self.store.audioPlaying,
                "audioTestEnabledMaster": fixture == nil || expectedEnabled,
                "menuInstalled": self.statusItem?.button?.action != nil,
                "menuBarVisibilityRequested": menuBarVisibilityRequested,
                "menuBarRestoredOnReopen": self.statusItem?.isVisible == true,
                "menuBarAnchorNearTop": menuBarAnchorNearTop,
                "menuBarImageAvailable": self.statusItem?.button?.image != nil,
                "quickControlsOpened": quickControlsOpened,
                "minimizeCommandWorks": minimized,
                "restoresMinimizedWindow": self.window?.isMiniaturized == false,
                "audioStopped": !self.store.audioPlaying
            ]
            report.merge(audioLibraryChecks) { _, result in result }
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
            self.window?.close()
            self.store.shutdown()
            NSApp.terminate(nil)
        }
    }
}
