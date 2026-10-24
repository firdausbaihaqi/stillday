import SwiftUI

@MainActor
struct MenuBarView: View {
    @ObservedObject var store: AppState
    var openSettings: () -> Void
    var openYouTube: () -> Void
    var quit: () -> Void

    private var path: String? { store.currentWallpaper ?? store.activePhase?.wallpapers.first }
    private var canChangeWallpaper: Bool { store.preferences.enabled && store.preferences.wallpaperEnabled && !(store.activePhase?.wallpapers.isEmpty ?? true) }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let path {
                    WallpaperImage(path: path, pixels: 900).frame(height: 230).clipped()
                } else {
                    Rectangle().fill(Palette.sidebar).frame(height: 230)
                        .overlay(Image(systemName: "sun.horizon").font(.system(size: 54, weight: .ultraLight)).foregroundStyle(Palette.accent))
                }
                LinearGradient(colors: [.clear, Color(red: 0.09, green: 0.14, blue: 0.11).opacity(0.7)], startPoint: .center, endPoint: .bottom)
                Button(action: openSettings) {
                    Image(systemName: "gearshape").font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                        .frame(width: 34, height: 34).background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.2)))
                }.buttonStyle(.plain).padding(16).help("Open Settings").accessibilityLabel("Open Settings")
                VStack(alignment: .leading, spacing: 5) {
                    Text((store.activePhase?.name ?? "YOUR DAY").uppercased())
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.8)
                    Text(path.map(imageTitle) ?? "Make room for a view.")
                        .font(.system(size: 23, weight: .medium, design: .rounded)).tracking(-0.4).lineLimit(2)
                }.foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).padding(22)
            }.frame(height: 230).clipped()

            VStack(spacing: 18) {
                HStack(spacing: 25) {
                    transport("Previous wallpaper", symbol: "backward.end.fill", size: 42, action: store.previousWallpaper).disabled(!canChangeWallpaper)
                    transport(store.preferences.enabled ? "Pause Stillday" : "Enable Stillday", symbol: store.preferences.enabled ? "pause.fill" : "play.fill", size: 62) {
                        store.update { $0.enabled.toggle() }
                    }
                    transport("Next wallpaper", symbol: "forward.end.fill", size: 42, action: store.nextWallpaper).disabled(!canChangeWallpaper)
                }
                HStack(spacing: 10) {
                    feature("Wallpaper", symbol: "desktopcomputer", enabled: store.preferences.wallpaperEnabled) { store.update { $0.wallpaperEnabled.toggle() } }
                    feature("Ambient sound", symbol: "waveform", enabled: store.preferences.audioEnabled) { store.update { $0.audioEnabled.toggle() } }
                }
                if store.preferences.audioEnabled {
                    HStack(spacing: 6) {
                        Image(systemName: store.audioPlaying ? "speaker.wave.2" : "speaker.slash")
                        Text(store.preferences.enabled ? store.audioStatus : "Sound paused with Stillday").lineLimit(1)
                    }.font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                if let phase = store.activePhase, !phase.wallpapers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 9) {
                            ForEach(phase.wallpapers, id: \.self) { path in
                                Button { store.useWallpaper(path) } label: {
                                    WallpaperImage(path: path, pixels: 180).frame(width: 62, height: 43).clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(self.path == path ? Palette.accent : .clear, lineWidth: 2))
                                }.buttonStyle(.plain).disabled(!canChangeWallpaper).help(imageTitle(path)).accessibilityLabel("Use \(imageTitle(path))")
                            }
                        }.padding(2)
                    }.frame(height: 47)
                }
                if store.activePhase?.audioSource == .youtube && store.preferences.enabled && store.preferences.audioEnabled {
                    Button("Show YouTube player", action: openYouTube).buttonStyle(.link).font(.system(size: 11))
                }
                if let error = store.error {
                    Text(error).font(.system(size: 10)).foregroundStyle(Palette.errorInk).lineLimit(2)
                }
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.preferences.enabled ? "Following your day" : "Scheduling paused").font(.system(size: 11, weight: .medium))
                        if let next = store.nextChange {
                            Text("Next phase · \(next.formatted(date: .omitted, time: .shortened))").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                        }
                    }
                    Spacer()
                    Button(action: quit) { Image(systemName: "power").font(.system(size: 13)).padding(8) }.buttonStyle(.plain).help("Quit Stillday").accessibilityLabel("Quit Stillday")
                }.padding(.top, 13).overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            }.padding(22)
        }
        .frame(width: 360)
        .foregroundStyle(Palette.ink).background(Palette.background)
        .tint(Palette.accent)
        .preferredColorScheme(store.preferences.appearance.colorScheme)
    }

    private func transport(_ title: String, symbol: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size == 62 ? 23 : 14, weight: .medium))
                .frame(width: size, height: size)
                .background(Palette.selection, in: Circle()).overlay(Circle().strokeBorder(Palette.line))
        }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
    private func feature(_ title: String, symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 17, weight: .regular))
                Text(title).font(.system(size: 11, weight: .medium))
                Text(enabled ? "On" : "Off").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
            }.frame(maxWidth: .infinity).padding(.vertical, 13)
                .foregroundStyle(enabled ? Palette.accent : Palette.muted)
                .background(enabled ? Palette.selection : .clear, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.line))
        }.buttonStyle(.plain).accessibilityLabel("\(title), \(enabled ? "on" : "off")")
    }
}
