import AppKit
import Foundation

/// Exercises the actual settings pages without desktop writes or audible playback.
@MainActor
enum NavigationBenchmark {
    static func run(store: AppState, navigation: SettingsNavigation) async {
        var rows: [[String: Any]] = []
        let clock = ContinuousClock()
        var previousTick = clock.now
        var worstGap = 0.0
        let heartbeat = Timer(timeInterval: 0.005, repeats: true) { _ in
            let now = clock.now
            let gap = milliseconds(previousTick.duration(to: now))
            worstGap = max(worstGap, gap)
            previousTick = now
        }
        RunLoop.main.add(heartbeat, forMode: .common)
        defer { heartbeat.invalidate() }
        try? await Task.sleep(for: .milliseconds(200))
        var destinations: [(name: String, page: String, phaseID: UUID?, images: [(String, Int)])] = store.sortedPhases.map { phase in
            var images = Array(store.library.prefix(5)).map { ($0, 380) }
            if let preview = phase.wallpapers.first { images.append((preview, 1400)) }
            return (phase.name, "phase", phase.id, images)
        }
        destinations.append(("Wallpaper library", "library", nil, Array(store.library.prefix(5)).map { ($0, 380) }))
        destinations.append(("Preferences", "general", nil, []))
        for pass in ["cold", "warm"] {
            if pass == "cold" { ImageCache.shared.clear() }
            for destination in destinations {
                navigation.page = destination.page == "general" ? "library" : "general"
                try? await Task.sleep(for: .milliseconds(80))
                worstGap = 0
                previousTick = clock.now
                let initialDecodes = ImageCache.shared.mainThreadDecodes
                let start = clock.now
                if let phaseID = destination.phaseID { navigation.selection = phaseID }
                navigation.page = destination.page
                // A queued main-loop turn measures whether rendering is blocked by image work.
                await withCheckedContinuation { continuation in
                    DispatchQueue.main.async { continuation.resume() }
                }
                let firstTurn = milliseconds(start.duration(to: clock.now))
                let expected = destination.images
                let deadline = clock.now.advanced(by: .seconds(10))
                while !expected.allSatisfy({ ImageCache.shared.contains(path: $0.0, pixels: $0.1) }), clock.now < deadline {
                    try? await Task.sleep(for: .milliseconds(10))
                }
                try? await Task.sleep(for: .milliseconds(50))
                rows.append([
                    "pass": pass, "phase": destination.name,
                    "firstMainTurnMs": firstTurn,
                    "imagesReadyMs": milliseconds(start.duration(to: clock.now)),
                    "maxMainLoopGapMs": worstGap,
                    "mainThreadDecodes": ImageCache.shared.mainThreadDecodes - initialDecodes,
                    "expectedImagesReady": expected.allSatisfy { ImageCache.shared.contains(path: $0.0, pixels: $0.1) }
                ])
            }
        }
        let report: [String: Any] = ["libraryCount": store.library.count, "desktopEffectsSuppressed": store.diagnosticMode, "rows": rows]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { print(String(decoding: data, as: UTF8.self)) }
    }
    nonisolated private static func milliseconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) * 1000 + Double(parts.attoseconds) / 1e15
    }
}
