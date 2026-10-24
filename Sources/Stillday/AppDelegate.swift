import AppKit
import Carbon
import Combine
import SwiftUI
import StilldayCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var store: AppState!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let diagnostic = ProcessInfo.processInfo.arguments.contains("--smoke-test")
        store = AppState(diagnosticMode: diagnostic)
        installAppMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sun.horizon", accessibilityDescription: "Stillday")
        statusItem = item
        store.onChange = { [weak self] in self?.refreshMenu() }
        store.start()
        refreshMenu()
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
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Stillday", action: #selector(quit), keyEquivalent: "q")
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
        let menu = NSMenu()
        menu.autoenablesItems = false
        let header = NSMenuItem(title: "Stillday  ·  \(store.activePhase?.name ?? "No phase")", action: nil, keyEquivalent: "")
        header.isEnabled = false; menu.addItem(header)
        if let next = store.nextChange, store.preferences.enabled {
            let label = NSMenuItem(title: "Next change at \(next.formatted(date: .omitted, time: .shortened))", action: nil, keyEquivalent: "")
            label.isEnabled = false; menu.addItem(label)
        }
        menu.addItem(.separator())
        add("Enable Stillday", action: #selector(toggleEnabled), state: store.preferences.enabled, to: menu)
        add("Wallpaper changes", action: #selector(toggleWallpaper), state: store.preferences.wallpaperEnabled, to: menu)
        let next = add("Next wallpaper", action: #selector(nextWallpaper), to: menu)
        next.isEnabled = store.preferences.enabled && store.preferences.wallpaperEnabled && !(store.activePhase?.wallpapers.isEmpty ?? true)
        if let phase = store.activePhase, !phase.wallpapers.isEmpty {
            let choose = NSMenuItem(title: "Choose wallpaper", action: nil, keyEquivalent: "")
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for path in phase.wallpapers {
                let entry = NSMenuItem(title: imageTitle(path), action: #selector(selectWallpaper(_:)), keyEquivalent: "")
                entry.target = self; entry.representedObject = path
                entry.state = store.currentWallpaper == path ? .on : .off
                entry.isEnabled = store.preferences.enabled && store.preferences.wallpaperEnabled
                submenu.addItem(entry)
            }
            choose.submenu = submenu; menu.addItem(choose)
        }
        menu.addItem(.separator())
        add("Ambient sound", action: #selector(toggleAudio), state: store.preferences.audioEnabled, to: menu)
        if store.preferences.audioEnabled {
            let label = NSMenuItem(title: store.audioStatus, action: nil, keyEquivalent: "")
            label.isEnabled = false; menu.addItem(label)
        }
        if let error = store.error {
            menu.addItem(.separator())
            let label = NSMenuItem(title: String(error.prefix(100)), action: nil, keyEquivalent: "")
            label.isEnabled = false; menu.addItem(label)
        }
        menu.addItem(.separator())
        add("Settings…", action: #selector(showSettings), to: menu).keyEquivalent = ","
        add("Quit Stillday", action: #selector(quit), to: menu).keyEquivalent = "q"
        statusItem?.menu = menu
        statusItem?.button?.appearsDisabled = !store.preferences.enabled
    }

    @discardableResult
    private func add(_ title: String, action: Selector, state: Bool? = nil, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let state { item.state = state ? .on : .off }
        menu.addItem(item)
        return item
    }

    @objc func showSettings() {
        if let window { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 790), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Stillday"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.94, alpha: 1)
        window.minSize = NSSize(width: 960, height: 700)
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
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
        ImageCache.shared.clear()
    }

    @objc private func toggleEnabled() { store.update { $0.enabled.toggle() } }
    @objc private func toggleWallpaper() { store.update { $0.wallpaperEnabled.toggle() } }
    @objc private func toggleAudio() { store.update { $0.audioEnabled.toggle() } }
    @objc private func nextWallpaper() { store.nextWallpaper() }
    @objc private func selectWallpaper(_ sender: NSMenuItem) { if let path = sender.representedObject as? String { store.useWallpaper(path) } }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            let audioWasPlaying = self.store.audioPlaying
            let expectedEnabled = self.store.preferences.enabled
            self.store.update { settings in settings.phases[1].startMinute = settings.phases[0].startMinute }
            let duplicateRejected = self.store.error != nil && Set(self.store.preferences.phases.map(\.startMinute)).count == self.store.preferences.phases.count
            self.store.update { $0.enabled = false }
            let report: [String: Any] = [
                "libraryCount": self.store.library.count,
                "phaseCount": self.store.preferences.phases.count,
                "activePhase": self.store.activePhase?.name ?? "none",
                "firstThumbnailLoaded": self.store.library.first.flatMap { ImageCache.shared.image(path: $0, pixels: 380) } != nil,
                "settingsWindowVisible": self.window?.isVisible == true,
                "desktopEffectsSuppressed": self.store.diagnosticMode,
                "localAudioStarted": fixture == nil || audioWasPlaying,
                "audioFixtureProvided": fixture != nil,
                "duplicateTimeRejected": duplicateRejected,
                "masterPauseStoppedAudio": !self.store.audioPlaying,
                "audioTestEnabledMaster": fixture == nil || expectedEnabled,
                "menuInstalled": self.statusItem?.menu != nil,
                "audioStopped": !self.store.audioPlaying
            ]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
            self.window?.close()
            self.store.shutdown()
            NSApp.terminate(nil)
        }
    }
}
