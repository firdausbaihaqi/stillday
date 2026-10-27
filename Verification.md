# Stillday verification

Verified on 24 October 2026 with Apple Silicon, macOS 26.5.1, and Swift 6.3.3 Command Line Tools. The deployment target remains macOS 14. Earlier macOS releases and Intel hardware were not exercised.

## 27 October: shared volume control

Version 0.4.1 adds a 0–100% volume slider to the shared audio controls, with a percentage label and accessible value. The main window, menu-bar panel, and Preferences use the same saved volume. It can be adjusted while sound is off and applies to active native playback and temporary selections through the existing reconciliation path.

`./scripts/build.sh` and `swift run StilldayChecks` passed (68/68 core assertions). The isolated native fixture verified actual player volume changes and mute without replacing the temporary selection; all playback, cancellation, and window assertions passed. See [volume report](docs/verification/volume-native.json). One initial fixed-delay playback assertion failed; it was replaced with a bounded wait for actual advancement before the passing rerun. The source change is in the test fixture, not the playback engine.

Native UI verification incremented the new slider from 0% to 1% in an isolated preview and confirmed Preferences also showed 1%. The installed 0.4.1 bundle passed strict signature validation. Audible output and remote YouTube volume were not separately measured; these changes reuse the existing volume handling.

## 27 October: Controls, audio library, and menu-bar permission coupling

Version 0.4.0 opens on Controls. The main window and menu-bar panel share the same controls and audio selection state. Audio library imports local files by reference, supports multiple selection, and removes references without deleting files or rewriting phase assignments. Older settings seed the library from existing phase tracks; an explicitly emptied library stays empty after reload.

Temporary track selection changes runtime playback only. It returns to the phase source at the captured next boundary, on Follow schedule, on removal of the selected entry, or after quitting. It survives pause/resume and window closing. Expiry uses a deadline as well as the phase identity, covering one-phase schedules and wake after a missed boundary. The timer honors the earlier of that deadline and the current schedule boundary, including while paused.

The menu-bar investigation found a reproducible permission coupling in the unchanged installed app: enabling **ChatGPT → Allow in the Menu Bar** produced an immediate ControlCenter `Unblocking host` event for Stillday, and the user confirmed the sunrise icon appeared. Restoring ChatGPT’s disabled setting produced `Moving host to blocked list` for the same Stillday process. The user then approved keeping ChatGPT enabled. Claude’s setting was left unchanged. This is a supported-UI workaround; the underlying cross-app permission association remains. No protected permission records, production bundle ID, or signing requirements were changed. The [CodexBar report](https://github.com/steipete/CodexBar/issues/1440) supplied the cross-app association hypothesis; the toggled Stillday result was verified locally rather than inferred from that report.

Validation:

- `swift run StilldayChecks`: **68/68** assertions passed, including 19 new library/migration/deadline assertions. New tests first failed compilation on the missing library and override APIs, then passed after implementation.
- `./scripts/build.sh`: release build passed. The new native regression checks first failed compilation on missing AppState override APIs, then built and ran after implementation.
- `./scripts/smoke-test.sh --audio-fixture=<muted generated WAV>`: real playback advanced through temporary selection and resume; selection preserved saved preferences; manual reset, expiry, missing selection rejection, reference-only removal, pending YouTube extraction replacement, and restoration of the scheduled YouTube source passed. See [path-free native report](docs/verification/audio-library-native.json).
- Minimize/restore, closing Settings with continued local playback, and regular/accessory activation policy checks passed in the isolated native fixture.
- Native UI: Controls enabled the muted fixture, the picker changed to Temporary audio with an expiry time, Audio library reflected the same selection, removal cleared it, and the native file chooser imported the WAV again. These preview operations used synthetic volatile settings. Production opened on Controls after installation, with personal settings still byte-identical to the pre-update backup.
- `git diff --check`, `plutil -lint Resources/Info.plist`, `zsh -n scripts/build.sh scripts/install.sh scripts/smoke-test.sh`, and strict bundle signature validation passed. No lint tool or coverage-percentage workflow is configured; no coverage percentage is claimed.

After installing 0.4.0 and reopening it from Applications, the user confirmed: **“Visible, and the updated controls open.”** This verifies actual icon visibility and physical click access to the updated panel, separately from the internal checks.

After that interaction, the persisted settings contained the new `audioLibraryPaths` field. All pre-existing fields, including complete phase assignments and the wallpaper library, still matched the backup.

The native report’s `menuBarAnchorNearTop: false` is retained honestly: its diagnostic identity does not prove production visibility. Visibility-request flags and programmatic popover opening remain internal checks. The old loose screen-intersection test was replaced with a top-edge geometry check. No overnight schedule run, new reboot cycle after installation, Intel/older macOS run, audible-listening test, or long YouTube stream replay was performed for this update. Background YouTube source restoration was checked at connection start, not as a completed network playback test.

## 26 October: menu-bar visibility remains under investigation

The user reports that the icon is still absent on both displays. The prior `NSStatusItem.isVisible` and display-intersection checks did not establish actual top-bar visibility: Apple's SDK documents that `isVisible` can remain true even when an item is obscured. In the closed-Settings probe, the NSStatusBarWindow reported `{{0, -7}, {38, 22}}`, which intersects the bottom of the primary display rather than its menu bar. Do not treat that intersection or a programmatic popover opening as proof that a user can see the icon.

System Settings listed two Stillday entries and an old baseline entry under Allow in the Menu Bar. Both Stillday switches were already on; they were toggled off and back on without changing other app controls. Subsequent user screenshots confirmed ample space and no Stillday icon on either display, so this was not a confirmed fix.

Version 0.3.1 restores the original `LSUIElement` background-app declaration and removes the initial runtime activation-policy switch. This is a startup-registration hypothesis, pending visual confirmation. Installation still places the app in Applications; Spotlight indexing found that copy after the agent flag was restored. The installer unregisters its build-output copy before registering the installed app. Native checks now run through `scripts/smoke-test.sh`, which signs a separate `day.stillday.checks` fixture so checks do not compete with the real app's status-item identity. The isolated fixture passed playback, minimize/close/reopen, and internal status-item checks. Those status-item checks still do not establish visual appearance. Build, installed signature, plist validation, and 49/49 core checks passed. The installed app was left running with Settings closed and Dock hidden.

## 25 October: installation and reopening

This experiment added a stable autosave identity, explicit visibility requests on launch/reopen, and an explicitly sized template image. The native checks deliberately hid the item, reopened the app, accepted a loose display intersection, and opened Quick Controls programmatically. Two launches recorded those internal checks as passing ([first](docs/verification/menu-bar-first-launch.json), [second](docs/verification/menu-bar-second-launch.json)); neither established actual icon visibility. The archived reports retain the original weak fields. Window activation policy and background playback passed, as did the release build, signature validation, and 49/49 core checks. The temporary always-visible Dock change was removed after clarifying which icon was missing.

`scripts/install.sh` built the app, installed it in `/Applications`, registered it with Launch Services, and opened it. That installation experiment temporarily removed the UI-element declaration; version 0.3.1 restored it. The runtime hides the Dock icon when Settings closes. Settings remains eligible for ⌘Tab while open. Spotlight metadata and `mdfind` identified the installed bundle, AppKit resolved its bundle identifier to the Applications copy, and the app appeared in the system application inventory. Minimizing Settings with ⌘W and reopening by bundle identifier restored the same window. Code-signature validation, plist validation, installer syntax validation, the running-app installer guard, and 49/49 core checks passed. Direct Spotlight UI automation timed out; Spotlight indexing was verified through its metadata tools.

## 25 October: background YouTube audio and standard Settings window

Follow-up fix for silent long tracks: the three-hour ambient track reproduced a native player stuck at zero playback time with the direct M4A URL. Its audio-only HLS stream started promptly and advanced normally. Resolution now prefers audio-only HLS, and streamed tracks start directly rather than waiting for AVPlayerLooper preparation. End-of-track handling resolves a fresh URL before repeating. Buffering is shown explicitly, item failures are surfaced, and a 30-second startup timeout prevents an indefinite silent wait.

The native checks now require actual playback-time advancement, including while minimized and after closing Settings. The affected long track passed these checks ([report](docs/verification/background-long-track.json)); a short public clip played through its end and successfully repeated ([report](docs/verification/background-repeat.json)). Local looping also passed with the stronger advancement assertions. These are muted native playback checks, not confirmation from a listener. The default macOS output device was available and unmuted.

The release build and **49/49** core regression checks passed. The additional core checks cover all audio-source values and compatibility with saved visible-player selections.

Native smoke runs used isolated settings and muted playback. A generated local WAV and a real public YouTube clip both reached AVFoundation’s playing state, stayed playing while Settings was minimized and after its window closed, and stopped when the app was paused. Settings reported the regular application policy while open and minimized, then accessory policy after closing. Minimize and restore passed. A pending yt-dlp extraction was started and canceled without later resuming audio. No yt-dlp or Deno process remained after the runs.

An unavailable YouTube video produced the expected connection error without reporting playback. Reports: [local audio](docs/verification/background-local.json), [YouTube audio](docs/verification/background-youtube.json), and [unavailable video](docs/verification/background-unavailable.json). Source-specific “started” flags are skipped when that source’s fixture is absent; use the `audioFixtureProvided` and `youtubeFixtureProvided` fields to identify the exercised source.

The standard Settings window and three source choices were inspected in the running app. Dock/⌘Tab eligibility was checked through AppKit’s regular application policy; direct inspection of the Dock through UI automation timed out. These checks do not establish long-running stream reliability or performance improvements. Signed stream URLs can expire; reconnect by toggling sound off and on. Earlier measurements and visible-player limitations below describe the previous version.

Reproduce with `./scripts/build.sh`, `swift run StilldayChecks`, and the native app executable:

```sh
./scripts/smoke-test.sh --audio-fixture=/absolute/path/to/test.wav
./scripts/smoke-test.sh '--youtube-fixture=https://youtu.be/jNQXAC9IVRw'
```

Background playback uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) only during stream resolution, followed by native AVQueuePlayer playback. [YouTubeKit](https://github.com/alexeichhorn/YouTubeKit) was also researched; its local extraction is an alternative, but the optional remote fallback forwards requests through a third-party server. Stillday uses neither that library nor its remote service. yt-dlp is installed separately with Homebrew and can be updated independently of Stillday. Local audio and the visible embedded player remain available without it.

## 0.3: motion, glass, shortcuts, and learning history

The release build and native smoke test passed, including real minimize/restore actions, local muted audio, master pause, image loading, and duplicate-time validation. A direct ⌘W keypress in the isolated preview produced the native `isMiniaturized == true` callback, and reopening Settings restored the window.

Native inspection covered light/dark glass, changes from cool lighthouse tones to warm field tones, phase/Library/Preferences navigation, local/YouTube form transitions, scene selection, transport controls, disabled states, and the Settings gear. UI preview settings were volatile; personal assignments and playback settings were preserved. Reduce Motion and Reduce Transparency paths were reviewed in source; the global macOS accessibility preferences were not changed during testing.

The full navigation replay loaded every expected image with zero main-thread decodes. Its path-free report is [navigation-motion-glass.json](docs/performance/navigation-motion-glass.json). The first queued main-loop turns ranged from about 23–129 ms in this run. These are input/layout measurements, not the duration of the intentional spring transitions or proof of a particular frame rate.

The first motion probe exposed an invalid benchmark setup: it cleared the cache while animated outgoing views retained cancelled loads. Cold runs now begin on the non-image Preferences page, and only preparation-page teardown disables animation. Production transitions remain enabled. The corrected run passed all destinations.

Every reconstructed code chapter passed its standalone core checks, and every chapter with an app target compiled as a native release executable. The first five chapters have 36 assertions; later chapters have 45. See [the learning guide](docs/LEARNING_PATH.md) for the exact commit sequence. The original published 0.2 tree is preserved exactly at chapter 7. The rewrite uses reconstructed logical checkpoints and current authoring dates.

## 0.2 navigation performance

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
- Memory use was not re-benchmarked for this update, so earlier 0.1 memory observations are not presented as current measurements.
- The app is locally ad hoc signed, not notarized. The repository contains source, its generated icon, and path-free test results, but no wallpapers, tracks, personal settings, credentials, or private machine paths.
