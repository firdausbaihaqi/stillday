# Stillday

Your own photos, changing with your day. Stillday is a small Mac app that switches wallpapers on a schedule and can play ambient sound alongside them.

Inspired by [Portal](https://portal.app), with a focus on a few everyday controls and your own local collection.

![Stillday showing its wallpaper preview, editable daily phases, and photo collection](docs/images/stillday.jpg)

*Preview with a personal photo collection. Wallpapers and audio are not included.*

## What it does

- Changes wallpapers through Morning, Noon, and Night, with names and times you can edit.
- Lets you pick the next wallpaper, pause the app, or switch sound on and off from the menu bar.
- Plays looping local audio or an optional YouTube video in a visible player.
- Follows your Mac’s light or dark appearance, or lets you choose either manually.
- Uses the current wallpaper to tint its glassy interface.

<details>
<summary>See the menu-bar controls</summary>

<img src="docs/images/quick-controls.jpg" alt="Stillday menu-bar panel with wallpaper thumbnails, previous and next controls, pause, and separate wallpaper and sound switches" width="360">

</details>

## Install

You’ll need **macOS 14 or later**. There isn’t a prebuilt download on GitHub yet, so installation currently involves building the app on your Mac.

### 1. Install Apple’s build tools

Open **Terminal** and run the following, then finish the installer. Skip this step if you already have a recent Xcode or Command Line Tools installation with Swift 5.10 or later.

```sh
xcode-select --install
```

### 2. Build Stillday

Once the tools are installed, run:

```sh
git clone https://github.com/firdausbaihaqi/stillday.git
cd stillday
./scripts/build.sh
open -R ../Stillday.app
```

Finder will show the newly built **Stillday.app**. Drag it into **Applications**, then open it.

This is an early build, signed locally rather than notarized by Apple. Move it to its final location before enabling **Launch at login**.

## Set up your day

Stillday starts paused on a fresh installation.

1. Open **Wallpaper library → Choose folder** and select a folder of photos.
2. Choose a phase in the sidebar, then click the photos you want to include in it.
3. Edit the phase’s name or start time if you like, then choose **Save phase**. The defaults are 6 am, noon, and 6 pm.
4. Turn on **Enable Stillday** at the bottom of the sidebar.

Each phase lasts until the next one begins, using your Mac’s local time. The first assigned photo is selected when a phase starts; use the menu-bar arrows or thumbnails to choose another.

Your original photos stay where they are. Stillday remembers their locations, so keep the selected folder available.

## Add some sound

Sound is optional and has its own switch.

- **Local audio:** choose a phase, select **Local audio**, and use **Choose…** to pick a track. Turn on **Ambient sound** to loop it while that phase is active.
- **YouTube:** select **YouTube**, paste a video link, and save it. Enable ambient sound, then press Play in the separate player window. Keep that player visible; closing it stops the sound. Some videos do not allow embedding, and playlist links are not supported.

Local audio is the lighter option. YouTube needs an internet connection, may show ads, and uses more memory.

## Everyday controls

Click the menu-bar icon for quick controls. The gear opens Settings, and the power button quits the app.

- **Wallpaper** and **Ambient sound** can be enabled independently.
- **Pause** stops scheduling and sound, leaving the current wallpaper in place.
- **⌘W** minimizes Settings while Stillday keeps running. Open Settings again to restore it.
- **Preferences** contains appearance, volume, and launch-at-login options.

Quitting also leaves the last wallpaper in place; Stillday does not automatically restore your previous wallpaper.

## For developers and curious readers

Built with Swift and Apple’s native frameworks, without third-party packages.

- [Learn the app through its commits](docs/LEARNING_PATH.md)
- [Read the test results, performance measurements, and current limitations](Verification.md)
- Run the regression checks with `swift run StilldayChecks`.

Settings are stored in `~/Library/Application Support/Stillday/settings.json`. Personal settings, photos, and audio are not stored in this repository.
