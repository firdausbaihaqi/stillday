import SwiftUI

/// A static, downsampled backdrop; only wallpaper changes crossfade. No continuous rendering loop.
struct WallpaperGlass: View {
    let path: String?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reducedTransparency

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.background
                if !reducedTransparency, let path {
                    WallpaperImage(path: path, pixels: 700)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(1.2)
                        .blur(radius: 28, opaque: true)
                        .overlay(scheme == .dark ? Color(red: 0.07, green: 0.1, blue: 0.09).opacity(0.68) : Color.white.opacity(0.7))
                }
            }.clipped()
        }
        .animation(Motion.fade, value: scheme)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
