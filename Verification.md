# Stillday 0.2 verification

Verified on 24 October 2026 with Apple Silicon, macOS 26.5.1, and Swift 6.3.3 Command Line Tools. The deployment target remains macOS 14. Earlier macOS releases and Intel hardware were not exercised.

## Navigation performance

The ECC benchmark-optimization-loop workflow was used: measure the existing path, isolate a hypothesis, run the replacement twice against the same input, check correctness, and then verify the completed themed app. The search was bounded to two implementation variants; only one was needed for the image-decoding bottleneck.

**Observed cause:** the original `@MainActor` image cache called `CGImageSourceCreateThumbnailAtIndex` synchronously from the view’s `.task`. Cold PNG decodes blocked the UI thread. The original Cold Morning page made six main-thread decodes and blocked the main loop for roughly 1.5 seconds.

**Change:** two actor workers perform decoding away from the main thread, one for large previews and one for thumbnails. Pending requests are shared, finished images use the existing 24 MiB cache budget, and clearing the cache invalidates older requests. The view shows a placeholder and ignores results after cancellation.

The benchmark renders the actual Settings window with a 21-image local collection. It schedules a main-loop heartbeat and measures the first queued main-thread turn after navigation. This is a responsiveness measurement, not a claim about GPU frame presentation or the instant every photograph becomes visible.

| Page | Original cold activation, two runs | Async loader alone, two runs | Completed themed app, two runs |
| --- | ---: | ---: | ---: |
| Morning | 1,476–1,622 ms | 62–67 ms | 107–202 ms |
| Noon | 338–342 ms | 61–62 ms | 82–190 ms |
| Night | 311–313 ms | 60–61 ms | 81–184 ms |
| Wallpaper library | Not separately baselined | Not separately measured | 35–74 ms |
| Preferences | Not separately baselined | Not separately measured | 54–72 ms |

All expected images became available in every run. The original phase-page runs made 16 main-thread decodes in total; both replacement runs and the completed app made **zero**. The final warm phase activations were 80–109 ms; warm Library/Preferences activations were 32–62 ms. Warm-cache navigation was not improved by moving decoding: the original warm phase measurements were 33–62 ms. The new themed interface has additional layout cost, and no universal speedup is claimed.

Cold images still require decoding. The completed app’s cold Morning “all expected images cached” measurement took roughly 3 seconds under this workload, while navigation and input were available earlier. Work has moved off the UI thread; it has not disappeared. At most two full-image decodes run concurrently to avoid trading responsiveness for unbounded memory use.

Raw, path-free reports are in [docs/performance](docs/performance). `navigation-baseline-*` and `navigation-async-*` are the repeated isolated before/after runs. `navigation-final*` covers all three phase pages, Library, and Preferences after appearance and popover work. A sampling profile also confirmed ImageIO work on worker threads; its instrumented timing was excluded from the comparison table.

Reproduce the current benchmark using a **copy** of your populated settings file:

```sh
./scripts/build.sh
STILLDAY_TEST_SETTINGS=/absolute/path/to/copied-settings.json \
  ../Stillday.app/Contents/MacOS/Stillday --benchmark-navigation
```

The historical baseline was measured before replacing the synchronous loader. Its captured reports are retained; the old binary and personal benchmark input are not published in the repository.

## Correctness and runtime checks

| Check | Result |
| --- | --- |
| `swift run StilldayChecks` | 45/45 assertions passed |
| Release `./scripts/build.sh` | Passed without compiler warnings |
| `--smoke-test --audio-fixture=<generated WAV>` with isolated settings | Passed: real window, thumbnail loading, native local playback, duplicate-time rejection, master pause, and status-button installation |
| `codesign --verify --deep --strict --verbose=2` | Local ad hoc signature valid |
| `plutil -lint` | Passed |
| Native phase/Library/Preferences navigation | Exercised in the real window and full benchmark |
| Appearance | System, Light, and Dark choices exercised; light/dark Settings and the dark popover visually inspected |
| Settings compatibility | A settings object without an appearance field decodes as System and preserves the other fields; all three modes round-trip |
| Popover | Opens, obtains keyboard focus, renders its image/controls, and dismisses with Escape |
| Popover actions | Master enable/pause, previous/next, independent wallpaper/audio switches, disabled states, and the Settings gear exercised in an isolated preview |

Core checks cover scheduling, midnight wrapping, custom phases, daylight-saving boundaries, forward/backward image cycling, validation, YouTube link validation, persistence, corrupt-file preservation, and appearance migration. The native smoke fixture loops muted; it is not a benchmark of long ambient recordings.

This workstation lacks XCTest/Swift Testing modules, so the project uses a standalone regression executable. No third-party packages or full Xcode installation were added. There is no configured lint tool beyond the Swift compiler and plist validator.

## State and limits

- Diagnostic and interactive-preview runs use copied settings, suppress desktop writes, and do not persist preference changes. The user’s existing phase assignments, master state, and audio state were retained. A matching currently displayed phase wallpaper is adopted on restart rather than being replaced by the phase’s first image.
- System appearance is inherited through native macOS appearance and SwiftUI. Returning from manual Light/Dark to System was tested against the current system appearance. The global macOS appearance preference was not changed during testing.
- Overnight transitions, a reboot/login cycle, and every multi-monitor/Space arrangement were not re-tested for this update. Scheduling and desktop integration retain the native path from 0.1.
- YouTube’s existing visible-player implementation was retained. YouTube playback was not re-tested for this UI update; the earlier 0.1 check verified load, play, mute, and stop. It still requires a visible player and can use substantially more memory than local audio.
- The app is approximately 1.9 MB on disk. Memory use was not re-benchmarked for 0.2, so earlier 0.1 memory observations are not presented as current measurements.
- The app is locally ad hoc signed, not notarized. The repository contains source, its generated icon, and path-free test results, but no wallpapers, tracks, personal settings, credentials, or private machine paths.
