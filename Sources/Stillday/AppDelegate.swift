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
        NSApp.setActivationPolicy(.accessory)
        let benchmark = ProcessInfo.processInfo.arguments.contains("--benchmark-navigation")
        let interactivePreview = ProcessInfo.processInfo.arguments.contains("--preview-controls")
        let diagnostic = ProcessInfo.processInfo.arguments.contains("--smoke-test") || benchmark || interactivePreview
        let settings = ProcessInfo.processInfo.environment["STILLDAY_TEST_SETTINGS"].map { URL(fileURLWithPath: $0) }
        store = AppState(diagnosticMode: diagnostic, settingsOverride: diagnostic ? settings : nil)
        installAppMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sun.horizon", accessibilityDescription: "Stillday")
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { store?.shutdown() }

    private func installAppMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Stillday", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        let controls = appMenu.addItem(withTitle: "Quick Controls", action: #selector(togglePopover), keyEquivalent: " ")
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
        panel.delegate = self
        let controller = NSHostingController(rootView: MenuBarView(store: store,
            openSettings: { [weak self] in self?.popover?.performClose(nil); self?.showSettings() },
            openYouTube: { [weak self] in self?.youtube?.showExisting() },
            quit: { NSApp.terminate(nil) }))
        controller.sizingOptions = [.preferredContentSize]
        panel.contentViewController = controller
        panel.contentSize = NSSize(width: 360, height: 562)
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
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Stillday"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.minSize = NSSize(width: 960, height: 700)
        window.contentView = NSHostingView(rootView: SettingsView(store: store, navigation: navigation))
        window.delegate = self
        window.isReleasedWhenClosed = false
        if !window.setFrameUsingName("StilldaySettings") { window.center() }
        window.setFrameAutosaveName("StilldaySettings")
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closed = notification.object as? NSWindow, closed === window else { return }
        closed.contentView = nil
        window = nil
        if popover?.isShown != true { ImageCache.shared.clear() }
    }

    @objc private func showAbout() { NSApp.orderFrontStandardAboutPanel(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func quit() { NSApp.terminate(nil) }

    private func runSmokeTest() {
        showSettings()
        let fixture = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--audio-fixture=") }).map { String($0.dropFirst("--audio-fixture=".count)) }
        if let fixture {
            store.update { settings in
                settings.wallpaperEnabled = false; settings.enabled = true; settings.audioEnabled = true; settings.volume = 0
                for index in settings.phases.indices { settings.phases[index].audioPath = fixture; settings.phases[index].audioSource = .local }
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self else { return }
            let audioWasPlaying = self.store.audioPlaying
            let expectedEnabled = self.store.preferences.enabled
            self.store.update { settings in settings.phases[1].startMinute = settings.phases[0].startMinute }
            let duplicateRejected = self.store.error != nil && Set(self.store.preferences.phases.map(\.startMinute)).count == self.store.preferences.phases.count
            self.store.update { $0.enabled = false }
            let thumbnailLoaded = if let path = self.store.library.first {
                await ImageCache.shared.image(path: path, pixels: 380) != nil
            } else { true }
            let report: [String: Any] = [
                "libraryCount": self.store.library.count,
                "phaseCount": self.store.preferences.phases.count,
                "activePhase": self.store.activePhase?.name ?? "none",
                "firstThumbnailLoaded": thumbnailLoaded,
                "settingsWindowVisible": self.window?.isVisible == true,
                "desktopEffectsSuppressed": self.store.diagnosticMode,
                "localAudioStarted": fixture == nil || audioWasPlaying,
                "audioFixtureProvided": fixture != nil,
                "duplicateTimeRejected": duplicateRejected,
                "masterPauseStoppedAudio": !self.store.audioPlaying,
                "audioTestEnabledMaster": fixture == nil || expectedEnabled,
                "menuInstalled": self.statusItem?.button?.action != nil,
                "audioStopped": !self.store.audioPlaying
            ]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
            self.window?.close()
            self.store.shutdown()
            NSApp.terminate(nil)
        }
    }
}
