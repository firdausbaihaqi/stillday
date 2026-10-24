import AppKit
import SwiftUI
import StilldayCore

private enum Palette {
    static let background = Color(red: 0.96, green: 0.96, blue: 0.94)
    static let sidebar = Color(red: 0.92, green: 0.93, blue: 0.90)
    static let ink = Color(red: 0.19, green: 0.23, blue: 0.21)
    static let muted = Color(red: 0.45, green: 0.49, blue: 0.45)
    static let accent = Color(red: 0.38, green: 0.47, blue: 0.34)
    static let line = Color(red: 0.84, green: 0.86, blue: 0.82)
}

@MainActor
struct SettingsView: View {
    @ObservedObject var store: AppState
    @State private var page = "phase"
    @State private var selection: UUID?
    @State private var showDelete = false

    private var phase: Phase? { store.preferences.phases.first { $0.id == selection } ?? store.activePhase ?? store.sortedPhases.first }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 216)
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(spacing: 0) {
                if let error = store.error {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                        Text(error).font(.system(size: 12)).textSelection(.enabled)
                        Spacer()
                        Button { store.dismissError() } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("Dismiss error")
                    }
                    .foregroundStyle(Color(red: 0.58, green: 0.29, blue: 0.18)).padding(14)
                    .background(Color(red: 0.98, green: 0.92, blue: 0.85))
                }
                if page == "library" { libraryPage }
                else if page == "general" { generalPage }
                else if let phase { phasePage(phase) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
        }
        .foregroundStyle(Palette.ink)
        .font(.system(size: 13))
        .tint(Palette.accent)
        .preferredColorScheme(.light)
        .frame(minWidth: 960, minHeight: 700)
        .onAppear { selection = store.activePhaseID }
        .confirmationDialog("Delete this phase? Its image files will stay in your folder.", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete phase", role: .destructive) {
                if let phase { store.deletePhase(phase.id); selection = store.sortedPhases.first?.id }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "sun.horizon.fill").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.accent)
                Text("Stillday").font(.system(size: 24, weight: .semibold, design: .rounded)).tracking(-0.8)
            }.padding(.top, 38).padding(.bottom, 5)
            Text("A little closer to outside.").font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.bottom, 36)
            HStack {
                eyebrow("YOUR RHYTHM")
                Spacer()
                Button {
                    if let id = store.addPhase() { selection = id; page = "phase" }
                } label: { Image(systemName: "plus").font(.system(size: 12, weight: .medium)) }
                .buttonStyle(.plain).help("Add a phase").accessibilityLabel("Add a phase")
            }.padding(.bottom, 12)
            ForEach(store.sortedPhases) { phase in
                Button {
                    selection = phase.id; page = "phase"
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: symbol(for: phase)).font(.system(size: 18, weight: .light)).frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phase.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                            Text(phase.timeLabel).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 2)
                        if store.activePhaseID == phase.id {
                            Circle().fill(Palette.accent).frame(width: 5, height: 5).help("Current scheduled phase")
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                    .background(page == "phase" && self.phase?.id == phase.id ? Color.white.opacity(0.75) : Color.clear, in: RoundedRectangle(cornerRadius: 11))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).padding(.horizontal, -10).padding(.bottom, 4)
            }
            Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 22)
            navButton("Wallpaper library", symbol: "square.grid.2x2", target: "library")
            navButton("Preferences", symbol: "slider.horizontal.3", target: "general")
            Spacer()
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text(store.preferences.enabled ? "Following your day" : "Scheduling paused").font(.system(size: 11, weight: .medium))
                    Spacer()
                    Toggle("Enable Stillday", isOn: Binding(get: { store.preferences.enabled }, set: { value in store.update { $0.enabled = value } })).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }
                if store.preferences.enabled, let next = store.nextChange {
                    Text("Next change at \(next.formatted(date: .omitted, time: .shortened))").font(.system(size: 10)).foregroundStyle(Palette.muted)
                } else { Text("Your wallpaper stays as it is.").font(.system(size: 10)).foregroundStyle(Palette.muted) }
            }
            .padding(.top, 18).overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 24).background(Palette.sidebar)
    }

    private func phasePage(_ phase: Phase) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        eyebrow("YOUR DAY, IN STILLS")
                        Text(phase.name).font(.system(size: 31, weight: .medium, design: .rounded)).tracking(-0.8)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle().fill(store.activePhaseID == phase.id ? Palette.accent : Palette.muted.opacity(0.5)).frame(width: 5, height: 5)
                        Text(store.activePhaseID == phase.id ? "CURRENT PHASE" : "STARTS AT \(phase.timeLabel)").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1)
                    }.padding(.top, 27)
                }
                let preview = (store.activePhaseID == phase.id ? store.currentWallpaper : nil) ?? phase.wallpapers.first
                ZStack(alignment: .bottomLeading) {
                    if let preview {
                        WallpaperImage(path: preview, pixels: 1400).frame(height: 254).clipped()
                        LinearGradient(colors: [.clear, Color(red: 0.07, green: 0.11, blue: 0.10).opacity(0.72)], startPoint: .center, endPoint: .bottom)
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(phase.wallpapers.count) WALLPAPERS IN THIS PHASE").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5)
                                Text(imageTitle(preview)).font(.system(size: 22, weight: .medium, design: .rounded))
                            }
                            Spacer()
                            Button {
                                store.useWallpaper(preview)
                            } label: {
                                Label("Set wallpaper", systemImage: "arrow.up.right").font(.system(size: 11, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 10)
                                    .background(.white.opacity(0.17), in: Capsule()).overlay(Capsule().strokeBorder(.white.opacity(0.25)))
                            }.buttonStyle(PressStyle()).disabled(!store.preferences.enabled || !store.preferences.wallpaperEnabled)
                        }.foregroundStyle(.white).padding(24)
                    } else {
                        Rectangle().fill(Palette.sidebar)
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 26, weight: .light))
                            Text("Give this part of your day a view.").font(.system(size: 21, weight: .medium, design: .rounded))
                            Text("Choose images from the library below.").foregroundStyle(Palette.muted)
                        }.padding(28)
                    }
                }.frame(height: 254).clipShape(RoundedRectangle(cornerRadius: 17))
                PhaseEditor(store: store, phase: phase).id(phase.id)
                Rectangle().fill(Palette.line).frame(height: 1)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("The view from here").font(.system(size: 17, weight: .medium, design: .rounded))
                        Text("Select images to include in \(phase.name.lowercased()).").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    if store.library.isEmpty { Button("Choose folder") { store.chooseFolder() } }
                    else { Text("\(phase.wallpapers.count) selected").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted) }
                }
                wallpaperGrid(phase: phase)
                if store.preferences.phases.count > 1 {
                    Button("Delete phase…", role: .destructive) { showDelete = true }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top, 8)
                }
            }.padding(32)
        }
    }

    private func wallpaperGrid(phase: Phase?) -> some View {
        let paths = Array(Set(store.library + (phase?.wallpapers ?? []))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 18) {
            ForEach(paths, id: \.self) { path in
                let selected = phase?.wallpapers.contains(path) ?? false
                Button {
                    if let phase { store.toggleAssignment(path: path, phaseID: phase.id) }
                    else { store.useWallpaper(path) }
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        WallpaperImage(path: path, pixels: 380)
                            .frame(height: 96).clipped().clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(alignment: .topTrailing) {
                                if selected { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white).padding(6).background(Palette.accent, in: Circle()).padding(7) }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Palette.accent : .clear, lineWidth: 2))
                        Text(imageTitle(path)).font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }.contentShape(Rectangle())
                }.buttonStyle(PressStyle()).help(phase == nil ? "Set this wallpaper" : "Include or remove this wallpaper")
            }
        }.overlay {
            if paths.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "folder.badge.plus").font(.system(size: 24, weight: .light))
                    Text("Your collection starts with a folder.").foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity).padding(36)
            }
        }.frame(minHeight: paths.isEmpty ? 140 : 0)
    }

    private var libraryPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                pageHeader("YOUR OWN COLLECTION", title: "Wallpaper library", subtitle: "Original files stay in your folder. Stillday only keeps their paths.")
                HStack {
                    Label("\(store.library.count) photographs", systemImage: "photo.stack").foregroundStyle(Palette.muted)
                    Spacer()
                    Button("Refresh") { store.refreshLibrary() }
                    Button("Choose folder…") { store.chooseFolder() }.buttonStyle(.borderedProminent)
                }
                Text(store.preferences.libraryFolder.isEmpty ? "No folder selected" : store.preferences.libraryFolder).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled)
                wallpaperGrid(phase: nil)
            }.padding(32)
        }
    }

    private var generalPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader("MADE TO STAY QUIET", title: "Preferences", subtitle: "A few controls, then back to your day.")
                VStack(spacing: 0) {
                    settingRow("Wallpaper changes", detail: "Follow your phase schedule on connected displays.") {
                        Toggle("Wallpaper changes", isOn: Binding(get: { store.preferences.wallpaperEnabled }, set: { value in store.update { $0.wallpaperEnabled = value } })).labelsHidden().toggleStyle(.switch)
                    }
                    Divider()
                    settingRow("Ambient sound", detail: "Use the audio source assigned to the current phase.") {
                        Toggle("Ambient sound", isOn: Binding(get: { store.preferences.audioEnabled }, set: { value in store.update { $0.audioEnabled = value } })).labelsHidden().toggleStyle(.switch)
                    }
                    Divider()
                    settingRow("Volume", detail: "\(Int(store.preferences.volume * 100)) percent") {
                        Slider(value: Binding(get: { store.preferences.volume }, set: { value in store.update { $0.volume = value } }), in: 0...1).frame(width: 170).accessibilityLabel("Ambient volume")
                    }
                    Divider()
                    settingRow("Launch at login", detail: "Start in the menu bar when you sign in.") {
                        Toggle("Launch at login", isOn: Binding(get: { store.loginEnabled }, set: { store.setLoginEnabled($0) })).labelsHidden().toggleStyle(.switch)
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Built to leave room.").font(.system(size: 18, weight: .medium, design: .rounded))
                    Text("Wallpapers use the macOS desktop engine. Local sound uses native playback. Previews are released when you close this window; the schedule wakes at the next phase boundary.").foregroundStyle(Palette.muted).lineSpacing(5)
                    Text("Pausing keeps the current wallpaper and stops sound. The schedule follows your Mac’s local clock; each phase ends when the next begins.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(4)
                }.padding(.top, 8)
                Button("Show settings file in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.settingsURL]) }.buttonStyle(.link).font(.system(size: 11))
                Spacer(minLength: 40)
                Text("STILLDAY  /  PERSONAL EDITION").font(.system(size: 9, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.muted)
            }.padding(32)
        }
    }

    private func settingRow<Control: View>(_ title: String, detail: String, @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) { Text(title).fontWeight(.medium); Text(detail).font(.system(size: 11)).foregroundStyle(Palette.muted) }
            Spacer(minLength: 24)
            control()
        }.padding(.vertical, 22)
    }
    private func navButton(_ title: String, symbol: String, target: String) -> some View {
        Button { page = target } label: {
            Label(title, systemImage: symbol).font(.system(size: 12)).padding(.vertical, 11).padding(.horizontal, 11).frame(maxWidth: .infinity, alignment: .leading)
                .background(page == target ? Color.white.opacity(0.75) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).padding(.horizontal, -10)
    }
    private func pageHeader(_ caption: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            eyebrow(caption)
            Text(title).font(.system(size: 30, weight: .medium, design: .rounded)).tracking(-0.7)
            Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted)
        }.padding(.bottom, 12)
    }
    private func symbol(for phase: Phase) -> String {
        switch phase.startMinute {
        case 300..<660: return "sun.horizon"
        case 660..<1020: return "sun.max"
        default: return "moon.stars"
        }
    }
}

@MainActor
private struct PhaseEditor: View {
    @ObservedObject var store: AppState
    let phase: Phase
    @State private var name: String
    @State private var time: Date
    init(store: AppState, phase: Phase) {
        self.store = store; self.phase = phase
        _name = State(initialValue: phase.name)
        // A stable reference day keeps clock-time editing independent of today's DST transition.
        _time = State(initialValue: Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: phase.startMinute / 60, minute: phase.startMinute % 60)) ?? Date())
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Phase name")
                    TextField("Morning", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("Phase name")
                }
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Starts at")
                    DatePicker("Starts at", selection: $time, displayedComponents: .hourAndMinute).labelsHidden().datePickerStyle(.field)
                }.frame(width: 128)
                Button("Save phase") {
                    var edited = phase; edited.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
                    edited.startMinute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                    store.updatePhase(edited)
                }.controlSize(.regular).disabled(name == phase.name && minute == phase.startMinute)
            }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 7) {

                        fieldLabel("Audio file")
                        HStack {
                            Text(phase.audioPath.isEmpty ? "No track selected" : URL(fileURLWithPath: phase.audioPath).lastPathComponent).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                            Spacer()
                            Button("Choose…") { store.chooseAudio(for: phase.id) }
                        }.frame(height: 24)
                        Text("Loops while this phase is active.").font(.system(size: 10)).foregroundStyle(Palette.muted)

                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    private var minute: Int { let parts = Calendar.current.dateComponents([.hour, .minute], from: time); return (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
    private func fieldLabel(_ title: String) -> some View { Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted) }
}

@MainActor
struct WallpaperImage: View {
    let path: String
    let pixels: Int
    @State private var image: NSImage?
    @State private var loaded = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.sidebar
                if let image { Image(nsImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped() }
                else if loaded { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(Palette.muted).accessibilityLabel("Image unavailable") }
                else { RoundedRectangle(cornerRadius: 8).fill(Palette.line.opacity(0.6)).padding(10).accessibilityLabel("Loading image") }
            }
        }
        .task(id: path) { loaded = false; image = ImageCache.shared.image(path: path, pixels: pixels); loaded = true }
    }
}

private struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1).opacity(configuration.isPressed ? 0.85 : 1)
    }
}
private func eyebrow(_ title: String) -> some View { Text(title).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.7).foregroundStyle(Palette.muted) }
func imageTitle(_ path: String) -> String {
    let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    return stem.replacingOccurrences(of: "^\\d+-", with: "", options: .regularExpression).replacingOccurrences(of: "-", with: " ").capitalized
}
