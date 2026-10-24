import AppKit
import AVFoundation
import Combine
import ImageIO
import ServiceManagement
import StilldayCore
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var preferences: Preferences
    @Published private(set) var library: [String] = []
    @Published private(set) var activePhaseID: UUID?
    @Published private(set) var currentWallpaper: String?
    @Published private(set) var audioPlaying = false
    @Published private(set) var error: String?
    @Published private(set) var audioStatus = "Ambient sound is off"
    @Published private(set) var loginEnabled = SMAppService.mainApp.status == .enabled
    var onChange: (() -> Void)?
    private var timer: Timer?
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playbackObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var audioFailureObservation: NSObjectProtocol?
    private var playingSource: String?
    private var observations: [NSObjectProtocol] = []
    private var lastAppliedByScreen: [String: String] = [:]
    private var canSave = true
    let settingsURL: URL
    let diagnosticMode: Bool

    init(diagnosticMode: Bool = false) {
        self.diagnosticMode = diagnosticMode
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        settingsURL = diagnosticMode
            ? FileManager.default.temporaryDirectory.appendingPathComponent("Stillday-smoke-\(ProcessInfo.processInfo.processIdentifier)/settings.json")
            : support.appendingPathComponent("Stillday/settings.json")
        var initial = Preferences()
        var loadError: String?
        var recoveryAllowsSaving = true
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            do { initial = try PreferenceFile.load(from: settingsURL) }
            catch {
                let backup = settingsURL.deletingLastPathComponent().appendingPathComponent("settings-unreadable-\(Int(Date().timeIntervalSince1970)).json")
                do {
                    try FileManager.default.copyItem(at: settingsURL, to: backup)
                    loadError = "Saved settings could not be read. A copy was kept at \(backup.lastPathComponent)."
                } catch {
                    recoveryAllowsSaving = false
                    loadError = "Saved settings could not be read or backed up. Repair the settings file in Finder, then restart Stillday. Saving is disabled to preserve your original file."
                }
            }
        }
        preferences = initial
        canSave = recoveryAllowsSaving
        error = loadError
        library = Self.imagePaths(in: initial.libraryFolder)
        activePhaseID = Schedule.phase(at: Date(), phases: initial.phases)?.id
        if diagnosticMode { preferences.enabled = false; preferences.audioEnabled = false }
    }

    var activePhase: Phase? { preferences.phases.first { $0.id == activePhaseID } }
    var sortedPhases: [Phase] { preferences.phases.sorted { $0.startMinute < $1.startMinute } }
    var nextChange: Date? { Schedule.nextBoundary(after: Date(), phases: preferences.phases) }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.screensDidWakeNotification] {
            observations.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reconcile(refreshScreens: true) }
            })
        }
        observations.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.stopAudio() }
        })
        for name in [NSApplication.didChangeScreenParametersNotification, NSNotification.Name.NSSystemTimeZoneDidChange, NSNotification.Name.NSSystemClockDidChange] {
            observations.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.reconcile(refreshScreens: true) }
            })
        }
        reconcile()
    }

    @discardableResult
    func update(_ mutation: (inout Preferences) -> Void) -> Bool {
        guard canSave else {
            error = "Saving is disabled because unreadable settings could not be backed up. Repair the settings file in Finder, then restart Stillday."
            onChange?()
            return false
        }
        var updated = preferences
        mutation(&updated)
        do {
            try updated.validate()
            if !diagnosticMode { try PreferenceFile.save(updated, to: settingsURL) }
            preferences = updated
            error = nil
            reconcile()
            return true
        } catch { self.error = error.localizedDescription; onChange?(); return false }
    }

    func updatePhase(_ value: Phase) {
        update { settings in
            guard let index = settings.phases.firstIndex(where: { $0.id == value.id }) else { return }
            settings.phases[index] = value
        }
    }

    func addPhase() -> UUID? {
        guard let minute = stride(from: 0, to: 1440, by: 60).first(where: { time in !preferences.phases.contains(where: { $0.startMinute == time }) }) else {
            error = "No unused hourly start time. Edit an existing phase first."
            return nil
        }
        let phase = Phase(name: "New phase", startMinute: minute)
        update { $0.phases.append(phase) }
        return preferences.phases.contains(where: { $0.id == phase.id }) ? phase.id : nil
    }

    func deletePhase(_ id: UUID) {
        guard preferences.phases.count > 1 else { error = "Keep at least one phase."; return }
        update { $0.phases.removeAll { $0.id == id } }
    }

    func toggleAssignment(path: String, phaseID: UUID) {
        update { settings in
            guard let index = settings.phases.firstIndex(where: { $0.id == phaseID }) else { return }
            if settings.phases[index].wallpapers.contains(path) { settings.phases[index].wallpapers.removeAll { $0 == path } }
            else { settings.phases[index].wallpapers.append(path) }
        }
    }

    func reconcile(refreshScreens: Bool = false) {
        timer?.invalidate()
        timer = nil
        let phase = Schedule.phase(at: Date(), phases: preferences.phases)
        if activePhaseID != phase?.id { currentWallpaper = nil }
        activePhaseID = phase?.id
        if refreshScreens { lastAppliedByScreen.removeAll() }
        if preferences.enabled, let phase {
            if preferences.wallpaperEnabled && !diagnosticMode {
                let path = currentWallpaper.flatMap { phase.wallpapers.contains($0) ? $0 : nil } ?? phase.wallpapers.first
                currentWallpaper = path
                if let path { applyWallpaper(path) }
            }
            reconcileAudio(phase)
        } else { stopAudio() }
        if preferences.enabled, let next = nextChange {
            let scheduled = Timer(fire: next.addingTimeInterval(0.15), interval: 0, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.reconcile() }
            }
            scheduled.tolerance = 1
            RunLoop.main.add(scheduled, forMode: .common)
            timer = scheduled
        }
        onChange?()
    }

    func useWallpaper(_ path: String) {
        guard preferences.enabled, preferences.wallpaperEnabled else {
            error = "Enable Stillday and wallpaper changes to apply a wallpaper."
            return
        }
        currentWallpaper = path
        applyWallpaper(path)
        onChange?()
    }

    func nextWallpaper() {
        guard let phase = activePhase, let path = Schedule.nextWallpaper(in: phase.wallpapers, current: currentWallpaper) else { return }
        useWallpaper(path)
    }

    private func applyWallpaper(_ path: String) {
        guard FileManager.default.isReadableFile(atPath: path) else {
            error = "Wallpaper is missing: \(URL(fileURLWithPath: path).lastPathComponent). Reconnect its folder or choose another image."
            return
        }
        let url = URL(fileURLWithPath: path)
        for screen in NSScreen.screens {
            let key = String(describing: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")])
            guard lastAppliedByScreen[key] != path || NSWorkspace.shared.desktopImageURL(for: screen) != url else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true])
                lastAppliedByScreen[key] = path
            } catch { self.error = "Could not change \(screen.localizedName): \(error.localizedDescription)" }
        }
    }

    private func reconcileAudio(_ phase: Phase) {
        guard preferences.audioEnabled else { stopAudio(); return }

        guard !phase.audioPath.isEmpty else { stopAudio(); audioStatus = "Choose a local track for \(phase.name)."; return }
        if playingSource == phase.audioPath, let player {
            player.volume = Float(preferences.volume)
            return
        }
        stopAudio()
        do {
            guard FileManager.default.isReadableFile(atPath: phase.audioPath) else { throw ValidationError("The audio file is missing or unreadable.") }
            let item = AVPlayerItem(url: URL(fileURLWithPath: phase.audioPath))
            item.preferredForwardBufferDuration = 5
            let audio = AVQueuePlayer()
            audio.volume = Float(preferences.volume)
            player = audio
            looper = AVPlayerLooper(player: audio, templateItem: item)
            playingSource = phase.audioPath
            playbackObservation = audio.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] audio, _ in
                let playing = audio.timeControlStatus == .playing
                Task { @MainActor in
                    guard let self, self.player === audio else { return }
                    self.audioPlaying = playing; self.onChange?()
                }
            }
            audioFailureObservation = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
                guard let failedItem = notification.object as? AVPlayerItem else { return }
                let message = failedItem.error?.localizedDescription ?? "The audio file could not be played."
                Task { @MainActor in self?.error = message; self?.stopAudio(); self?.onChange?() }
            }
            itemStatusObservation = audio.currentItem?.observe(\.status, options: [.initial, .new]) { [weak self, weak audio] item, _ in
                guard item.status == .failed else { return }
                let message = item.error?.localizedDescription ?? "This audio format could not be played."
                Task { @MainActor in
                    guard let self, let audio, self.player === audio else { return }
                    self.stopAudio(); self.error = message; self.onChange?()
                }
            }
            audio.play()
            audioStatus = URL(fileURLWithPath: phase.audioPath).deletingPathExtension().lastPathComponent
        } catch { self.error = "Could not play ambient audio: \(error.localizedDescription)"; audioStatus = "Audio unavailable" }
    }

    func stopAudio() {
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        playbackObservation?.invalidate()
        playbackObservation = nil
        if let audioFailureObservation { NotificationCenter.default.removeObserver(audioFailureObservation) }
        audioFailureObservation = nil
        player?.pause()
        looper?.disableLooping()
        looper = nil
        player?.removeAllItems()
        player = nil
        playingSource = nil
        audioPlaying = false
        audioStatus = "Ambient sound is off"
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose your wallpaper folder"
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let paths = Self.imagePaths(in: folder.path)
        guard !paths.isEmpty else { error = "This folder has no supported images. Choose a folder containing PNG, JPEG, HEIC, TIFF, or WebP files."; return }
        if update({ $0.libraryFolder = folder.path }) { library = paths }
    }

    func refreshLibrary() {
        library = Self.imagePaths(in: preferences.libraryFolder)
        if library.isEmpty { error = "No readable images were found. Check that the wallpaper folder is still available." }
        onChange?()
    }

    func chooseAudio(for id: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Choose a local ambient track"
        panel.allowedContentTypes = [.audio]
        guard panel.runModal() == .OK, let url = panel.url,
              var phase = preferences.phases.first(where: { $0.id == id }) else { return }
        phase.audioPath = url.path; phase.audioSource = .local
        updatePhase(phase)
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if enabled && !loginEnabled { error = "Approve Stillday in System Settings → General → Login Items." }
        } catch { self.error = "Could not update launch at login: \(error.localizedDescription)" }
    }

    func dismissError() { error = nil }
    func shutdown() { timer?.invalidate(); stopAudio() }

    static func imagePaths(in folder: String) -> [String] {
        guard !folder.isEmpty else { return [] }
        let types = Set(["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "webp"])
        return ((try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: folder), includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])) ?? [])
            .filter { types.contains($0.pathExtension.lowercased()) && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }
            .map(\.path).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()
    init() { cache.totalCostLimit = 24 * 1024 * 1024; cache.countLimit = 60 }
    func image(path: String, pixels: Int) -> NSImage? {
        let key = "\(path)|\(pixels)" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }
    func clear() { cache.removeAllObjects() }
}
