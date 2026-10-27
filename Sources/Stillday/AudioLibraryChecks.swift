import Foundation
import StilldayCore

@MainActor
enum AudioLibraryChecks {
    static func run(store: AppState, fixture: String) async -> [String: Bool] {
        let original = store.preferences
        let alternative = URL(fileURLWithPath: fixture).deletingLastPathComponent().appendingPathComponent("override-\(UUID().uuidString).wav")
        do { try FileManager.default.copyItem(at: URL(fileURLWithPath: fixture), to: alternative) }
        catch { return ["audioOverrideFixtureCreated": false] }
        defer { try? FileManager.default.removeItem(at: alternative) }
        let phases = store.preferences.phases
        store.addAudio([fixture, alternative.path, fixture])
        let libraryDeduplicated = store.preferences.audioLibraryPaths.filter { $0 == fixture }.count == 1
        let saved = store.preferences
        store.selectAudio(alternative.path)
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while (!store.audioPlaying || store.audioPlaybackSeconds < 0.25), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let playsOverride = store.audioPlaying && store.audioPlaybackSeconds >= 0.25 && store.effectiveAudioPath == alternative.path
        let defaultsUnchanged = store.preferences == saved
        store.update { $0.volume = 0.23 }
        let volumeUpdatedLive = abs((store.audioPlaybackVolume ?? -1) - 0.23) < 0.001 && store.audioOverride?.path == alternative.path
        store.update { $0.volume = 0 }
        let volumeMutedLive = store.audioPlaybackVolume == 0 && store.audioOverride?.path == alternative.path
        store.update { $0.enabled = false }
        let overrideWhilePaused = store.audioOverride?.path == alternative.path && !store.audioPlaying
        store.update { $0.enabled = true }
        let resumedDeadline = ContinuousClock.now.advanced(by: .seconds(5))
        while (!store.audioPlaying || store.audioPlaybackSeconds < 0.25), ContinuousClock.now < resumedDeadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let overrideResumed = store.audioOverride?.path == alternative.path && store.audioPlaying && store.audioPlaybackSeconds >= 0.25
        store.followAudioSchedule()
        let followsSchedule = store.audioOverride == nil && store.effectiveAudioPath == fixture
        store.update { settings in
            for index in settings.phases.indices {
                settings.phases[index].audioSource = .youtubeAudio
                settings.phases[index].youtubeURL = "https://youtu.be/BaW_jenozKc"
            }
        }
        let extractionStarted = store.audioStatus == "Connecting to YouTube audio…"
        store.selectAudio(alternative.path)
        let replacementDeadline = ContinuousClock.now.advanced(by: .seconds(5))
        while (!store.audioPlaying || store.audioPlaybackSeconds < 0.25), ContinuousClock.now < replacementDeadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
        let overrideReplacedExtraction = extractionStarted && store.effectiveAudioPath == alternative.path && store.audioPlaying && store.audioPlaybackSeconds > 0.25
        store.followAudioSchedule()
        let restoredYouTube = store.effectiveAudioSource == .youtubeAudio && store.audioStatus == "Connecting to YouTube audio…"
        store.update { $0 = saved }
        store.selectAudio(alternative.path)
        if let expiry = store.audioOverride?.expiresAt { store.reconcile(at: expiry) }
        let expired = store.audioOverride == nil
        store.selectAudio(alternative.path)
        store.removeAudio(alternative.path)
        let removalPreservedFile = FileManager.default.fileExists(atPath: alternative.path) && store.preferences.phases == phases
        let removalRestoredSchedule = store.audioOverride == nil && store.effectiveAudioPath == fixture
        let beforeMissing = store.preferences
        store.selectAudio(alternative.path + ".missing")
        let missingRejected = store.audioOverride == nil && store.preferences == beforeMissing && store.error != nil
        store.dismissError()
        store.update { $0 = original }
        return [
            "audioLibraryDeduplicated": libraryDeduplicated,
            "audioOverrideAdvanced": playsOverride,
            "audioOverridePreservedDefaults": defaultsUnchanged,
            "volumeUpdatedLive": volumeUpdatedLive,
            "volumeMutedLive": volumeMutedLive,
            "audioOverrideSurvivedPause": overrideWhilePaused,
            "audioOverrideResumed": overrideResumed,
            "followAudioScheduleRestoredSource": followsSchedule,
            "audioOverrideReplacedPendingExtraction": overrideReplacedExtraction,
            "followAudioScheduleRestoredYouTube": restoredYouTube,
            "audioOverrideExpiredAtBoundary": expired,
            "audioRemovalPreservedFileAndPhases": removalPreservedFile,
            "audioRemovalRestoredSchedule": removalRestoredSchedule,
            "missingAudioSelectionRejected": missingRejected
        ]
    }
}
