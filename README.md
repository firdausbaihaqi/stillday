# Stillday

A small native macOS app for wallpaper schedules and ambient audio. Create time-of-day phases, assign your own photographs, and control the day from the menu bar.

**Inspired by [Portal](https://portal.app).** Stillday is an independent personal alternative focused on local wallpapers and a minimal feature set. It does not include Portal’s code or media.

## Learn the implementation

Follow the [chapter-by-chapter commit guide](docs/LEARNING_PATH.md) to study the scheduling core, native APIs, audio, concurrency, appearance, controls, and motion in buildable steps.

## Features

- Editable phases, starting with Morning, Noon, and Night. Add, rename, or remove phases and set their start times.
- Local wallpaper folders, per-phase image assignments, and previous/next controls.
- A photo-backed menu-bar popover with master pause, wallpaper/audio switches, thumbnails, and a Settings shortcut.
- System, Light, and Dark appearances, saved across launches.
- Wallpaper-derived glass surfaces, short page/image transitions, and hover/press/focus feedback.
- ⌘W minimizes Settings while the menu-bar app keeps running; Settings restores the window.
- Looping local audio or an optional visible YouTube player per phase.
- Independent wallpaper and sound switches, volume, and optional launch at login.

The app uses Swift, SwiftUI, AppKit, ImageIO, and AVFoundation. No third-party packages or bundled web engine are required. YouTube uses the system’s WebKit only when requested.

## Build

Requires macOS 14 or later and Apple’s Swift 5.10+ toolchain. The standalone checks also work with Command Line Tools installations that do not include XCTest.

```sh
git clone https://github.com/firdausbaihaqi/stillday.git
cd stillday
swift run StilldayChecks
./scripts/build.sh
open ../Stillday.app
```

The script produces an optimized `.app` bundle beside the repository and signs it ad hoc for local use. It builds for the host architecture; an Apple Silicon build is not an Intel/universal distribution. No Developer ID certificate or notarization is configured.

An optional `STILLDAY_BUILD_DIR` environment variable selects a scratch/build directory outside the repository.

## Use

The app starts paused. Open **Wallpaper library → Choose folder**, then select images inside each phase to assign them. Original files remain in their folder and are never copied or modified. Existing assignments from older folders remain visible and removable in their phase.

The default times are **06:00**, **12:00**, and **18:00**. These are editable clock-time defaults. Each phase lasts until the next one starts, including across midnight, and follows the Mac’s local time zone. The first assigned image is selected when a phase begins; the menu-bar controls cycle through the current phase’s images.

Click the menu-bar icon for Quick Controls. The gear opens the dedicated Settings window. Closing Settings keeps the menu-bar app running. Pausing or quitting stops audio and leaves the last wallpaper in place. The app does not restore the previous macOS wallpaper automatically.

Choose **Preferences → Appearance → System / Light / Dark** to control the interface. System follows macOS appearance automatically; manual choices affect Stillday only.

### Local audio

Choose a local audio file for each phase, then enable Ambient sound and the master switch. Tracks use native buffered playback and loop. Supported formats depend on macOS; M4A, MP3, WAV, and AIFF are typical choices. No ambient tracks are bundled.

### YouTube

Select YouTube as the phase’s audio source, paste an HTTPS video link, and save it. Enable ambient sound and press Play in the visible player. Closing the player disables ambient sound. Minimizing or obscuring it requests a pause; **Show YouTube player** brings it back.

Stillday uses YouTube’s official embedded player and does not extract or download audio. Video owners, regional/account restrictions, and network failures may prevent embedding. Playlist links are not supported. YouTube can show ads, contacts Google/YouTube, and uses substantially more memory than local audio. The player uses a nonpersistent web session, which is released when stopped; WebKit helpers may persist temporarily.

See [YouTube’s player requirements](https://developers.google.com/youtube/terms/required-minimum-functionality) and [policy guide](https://developers.google.com/youtube/terms/developer-policies-guide) for the visible-player and background-playback constraints.

## Motion and glass

Both the menu-bar panel and Settings use a zoomed, downsampled version of the active wallpaper as a static blurred backdrop. Adaptive veils preserve text contrast in light and dark modes. Scene changes crossfade when the replacement image is ready.

Page transitions, the sidebar indicator, image fades, selection counts, audio forms, symbols, buttons, and fields have short feedback animations. Native controls retain their system interaction behavior. Reduce Motion disables page offsets and hover/press scaling and reduces other feedback; Reduce Transparency uses opaque surfaces. No perpetual animation runs while the app is idle.

## Performance

ImageIO decoding runs on two bounded background workers: one for large previews and one for thumbnails. Concurrent requests for the same image share a task. The main thread receives decoded images, and cancelled views do not display stale results. A 24 MiB cache budget limits retained previews. Closing the last Settings/popover view clears the cache and cancels queued work.

This replaced synchronous decoding that blocked cold page switches for over a second. See [Verification.md](Verification.md) for repeated before/after measurements, exact scope, and remaining verification limits. Image-loading time and interface responsiveness are reported separately.

Static wallpapers are handed to macOS; Stillday has no wallpaper rendering loop. Scheduling uses a one-shot timer at the next phase boundary plus native clock, wake, Space, and display notifications.

## Checks and benchmarks

```sh
swift run StilldayChecks
./scripts/build.sh
../Stillday.app/Contents/MacOS/Stillday --smoke-test
```

The smoke test uses temporary settings and suppresses desktop writes. Pass `--audio-fixture=/absolute/path/to/test.wav` to verify muted local playback and master pause.

For a navigation benchmark with your own library, provide a **copy** of a populated settings file. Diagnostic modes suppress desktop effects, audio, and settings writes:

```sh
STILLDAY_TEST_SETTINGS=/absolute/path/to/copied-settings.json \
  ../Stillday.app/Contents/MacOS/Stillday --benchmark-navigation
```

The benchmark drives the real Settings pages and reports cold/warm first-main-loop-turn latency, worst main-loop gap, time until expected preview images are cached, and the number of main-thread decodes. The same diagnostic settings can be used with `--preview-controls` for isolated interactive inspection.

## Storage and desktop behavior

Settings are stored in `~/Library/Application Support/Stillday/settings.json`. Older settings without an appearance field migrate to System mode. Unreadable settings are backed up before recovery; saving is blocked if a backup fails. Personal settings, wallpaper files, audio files, and benchmark inputs are not part of this repository.

This personal build is not sandboxed. It reads selected local paths and writes its own settings. Launch at login is opt-in and subject to macOS approval; move the app to its final location before enabling it.

The selected wallpaper is applied to connected displays using Apple’s public desktop-image API. Inactive Spaces are updated when activated. Lock-screen behavior remains controlled by macOS. No private wallpaper databases are modified.
