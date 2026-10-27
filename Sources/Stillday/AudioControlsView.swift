import AppKit
import SwiftUI

@MainActor
struct AudioControlsView: View {
    @ObservedObject var store: AppState

    private var canPlay: Bool { store.preferences.enabled && store.preferences.audioEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(store.audioOverride == nil ? "Following schedule" : "Temporary audio", systemImage: store.audioOverride == nil ? "clock" : "waveform")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                if store.audioOverride != nil {
                    Button("Follow schedule") { store.followAudioSchedule() }
                        .buttonStyle(.link).font(.system(size: 11))
                }
            }
            Picker("Audio track", selection: Binding(get: { store.audioOverride?.path ?? "" }, set: { path in
                if path.isEmpty { store.followAudioSchedule() }
                else { store.selectAudio(path) }
            })) {
                Text("Use phase audio").tag("")
                ForEach(store.preferences.audioLibraryPaths, id: \.self) { path in
                    let readable = FileManager.default.isReadableFile(atPath: path)
                    Text("\(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)\(readable ? "" : " · Missing")")
                        .tag(path).disabled(!readable)
                }
            }.labelsHidden().disabled(!canPlay).accessibilityLabel("Audio track")
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: store.audioPlaying ? "speaker.wave.2" : "speaker.slash")
                Text(!store.preferences.enabled ? "Sound paused with Stillday" : !store.preferences.audioEnabled ? "Turn on Ambient sound to choose a track." : store.audioStatus)
                    .lineLimit(2).help(store.audioStatus)
            }.font(.system(size: 10)).foregroundStyle(Palette.muted)
            if let selection = store.audioOverride {
                Text("Returns to phase audio at \(selection.expiresAt.formatted(date: .omitted, time: .shortened)).")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
            } else if store.preferences.audioLibraryPaths.isEmpty {
                Text("Add local tracks in Audio library to switch sound here.")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}
