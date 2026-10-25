import AppKit
import SwiftUI
import StilldayCore

@MainActor
struct SettingsView: View {
    @ObservedObject var store: AppState
    @ObservedObject var navigation: SettingsNavigation
    @State private var showDelete = false
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Namespace private var selectionIndicator

    private var pageID: String { navigation.page == "phase" ? phase?.id.uuidString ?? "empty" : navigation.page }

    private var phase: Phase? { store.preferences.phases.first { $0.id == navigation.selection } ?? store.activePhase ?? store.sortedPhases.first }

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
                        Button { store.dismissError() } label: { Image(systemName: "xmark") }.buttonStyle(InteractiveButtonStyle()).help("Dismiss error")
                    }
                    .foregroundStyle(Palette.errorInk).padding(14)
                    .background(Palette.errorBackground)
                }
                ZStack(alignment: .topLeading) {
                    Group {
                        if navigation.page == "library" { libraryPage }
                        else if navigation.page == "general" { generalPage }
                        else if let phase { phasePage(phase) }
                    }
                    .id(pageID)
                    .transition(reducedMotion ? .opacity : .opacity.combined(with: .offset(x: 10)))
                }
                .animation(Motion.page(reducedMotion), value: pageID)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background.opacity(0.18))
        }
        .background(WallpaperGlass(path: store.currentWallpaper ?? store.activePhase?.wallpapers.first))
        .foregroundStyle(Palette.ink)
        .font(.system(size: 13))
        .tint(Palette.accent)
        .preferredColorScheme(store.preferences.appearance.colorScheme)
        .frame(minWidth: 960, minHeight: 700)
        .onAppear { navigation.selection = store.activePhaseID }
        .animation(Motion.feedback(reducedMotion), value: navigation.selection)
        .animation(Motion.feedback(reducedMotion), value: navigation.page)
        .animation(Motion.fade, value: store.error)
        .confirmationDialog("Delete this phase? Its image files will stay in your folder.", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete phase", role: .destructive) {
                if let phase { store.deletePhase(phase.id); navigation.selection = store.sortedPhases.first?.id }
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
                    if let id = store.addPhase() { navigation.selection = id; navigation.page = "phase" }
                } label: { Image(systemName: "plus").font(.system(size: 12, weight: .medium)) }
                .buttonStyle(InteractiveButtonStyle()).help("Add a phase").accessibilityLabel("Add a phase")
            }.padding(.bottom, 12)
            ForEach(store.sortedPhases) { phase in
                Button {
                    navigation.selection = phase.id; navigation.page = "phase"
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
                    .background { selectionBackground(navigation.page == "phase" && self.phase?.id == phase.id) }
                    .contentShape(Rectangle())
                }.buttonStyle(InteractiveButtonStyle()).padding(.horizontal, -10).padding(.bottom, 4)
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
        .padding(.horizontal, 24).background(Palette.sidebar.opacity(0.55))
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
                        WallpaperImage(path: preview, pixels: 1400, contentMode: .fit)
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
                            }.buttonStyle(InteractiveButtonStyle()).disabled(!store.preferences.enabled || !store.preferences.wallpaperEnabled)
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
                    else { Text("\(phase.wallpapers.count) selected").font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted)
                        .contentTransition(.numericText()).animation(Motion.feedback(reducedMotion), value: phase.wallpapers.count) }
                }
                wallpaperGrid(phase: phase)
                if store.preferences.phases.count > 1 {
                    Button("Delete phase…", role: .destructive) { showDelete = true }.buttonStyle(InteractiveButtonStyle()).font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.top, 8)
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
                                if selected { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white).padding(6).background(Palette.accent, in: Circle()).padding(7).transition(reducedMotion ? .opacity : .scale.combined(with: .opacity)) }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Palette.accent : .clear, lineWidth: 2))
                            .animation(Motion.feedback(reducedMotion), value: selected)
                        Text(imageTitle(path)).font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }.contentShape(Rectangle())
                }.buttonStyle(InteractiveButtonStyle()).help(phase == nil ? "Set this wallpaper" : "Include or remove this wallpaper")
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
                    settingRow("Appearance", detail: "Follow macOS, or choose a look for Stillday.") {
                        Picker("Appearance", selection: Binding(get: { store.preferences.appearance }, set: { value in store.update { $0.appearance = value } })) {
                            Text("System").tag(AppAppearance.system)
                            Text("Light").tag(AppAppearance.light)
                            Text("Dark").tag(AppAppearance.dark)
                        }.labelsHidden().pickerStyle(.segmented).frame(width: 210)
                    }
                    Divider()
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
    @ViewBuilder
    private func selectionBackground(_ selected: Bool) -> some View {
        if selected {
            RoundedRectangle(cornerRadius: 11)
                .fill(Palette.selection.opacity(0.72))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(.white.opacity(0.12)))
                .matchedGeometryEffect(id: "navigation-selection", in: selectionIndicator, properties: reducedMotion ? [] : .frame)
        }
    }

    private func navButton(_ title: String, symbol: String, target: String) -> some View {
        Button { navigation.page = target } label: {
            Label(title, systemImage: symbol).font(.system(size: 12)).padding(.vertical, 11).padding(.horizontal, 11).frame(maxWidth: .infinity, alignment: .leading)
                .background { selectionBackground(navigation.page == target) }
        }.buttonStyle(InteractiveButtonStyle()).padding(.horizontal, -10)
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
    @State private var youtube: String
    @Environment(\.accessibilityReduceMotion) private var formReducedMotion
    init(store: AppState, phase: Phase) {
        self.store = store; self.phase = phase
        _name = State(initialValue: phase.name)
        // A stable reference day keeps clock-time editing independent of today's DST transition.
        _time = State(initialValue: Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: phase.startMinute / 60, minute: phase.startMinute % 60)) ?? Date())
        _youtube = State(initialValue: phase.youtubeURL)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Phase name")
                    TextField("Morning", text: $name).textFieldStyle(.roundedBorder).modifier(FieldFeedback()).accessibilityLabel("Phase name")
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
                    fieldLabel("Ambient source")
                    Picker("Ambient source", selection: Binding(get: { phase.audioSource }, set: { value in var edited = phase; edited.audioSource = value; store.updatePhase(edited) })) {
                        Text("Local audio").tag(AudioSource.local)
                        Text("YouTube audio").tag(AudioSource.youtubeAudio)
                        Text("YouTube player").tag(AudioSource.youtube)
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 310)
                }
                VStack(alignment: .leading, spacing: 7) {
                    if phase.audioSource == .local {
                        fieldLabel("Audio file")
                        HStack {
                            Text(phase.audioPath.isEmpty ? "No track selected" : URL(fileURLWithPath: phase.audioPath).lastPathComponent).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1)
                            Spacer()
                            Button("Choose…") { store.chooseAudio(for: phase.id) }
                        }.frame(height: 24)
                        Text("Loops while this phase is active.").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    } else {
                        fieldLabel("YouTube video link")
                        HStack {
                            TextField("https://www.youtube.com/watch?v=…", text: $youtube).textFieldStyle(.roundedBorder).modifier(FieldFeedback()).accessibilityLabel("YouTube video link")
                            Button("Save") {
                                let value = youtube.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard value.isEmpty || YouTube.videoID(from: value) != nil else { return }
                                var edited = phase; edited.youtubeURL = value; store.updatePhase(edited)
                            }.disabled((!youtube.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && YouTube.videoID(from: youtube) == nil) || youtube == phase.youtubeURL)
                        }
                        Text(youtube.isEmpty || YouTube.videoID(from: youtube) != nil ? (phase.audioSource == .youtubeAudio ? "Plays in the background with yt-dlp. Install once: brew install yt-dlp." : "Plays in a visible player window; uses more memory than local audio.") : "Enter an HTTPS YouTube video link, not a playlist.").font(.system(size: 10)).foregroundStyle(Palette.muted)
                        HStack(spacing: 12) {
                            Link("YouTube terms", destination: URL(string: "https://www.youtube.com/t/terms")!)
                            Link("Google privacy", destination: URL(string: "https://policies.google.com/privacy")!)
                        }.font(.system(size: 9))
                    }
                }.id(phase.audioSource).transition(.opacity).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(Motion.page(formReducedMotion), value: phase.audioSource)
    }
    private var minute: Int { let parts = Calendar.current.dateComponents([.hour, .minute], from: time); return (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
    private func fieldLabel(_ title: String) -> some View { Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted) }
}

@MainActor
struct WallpaperImage: View {
    let path: String
    let pixels: Int
    var contentMode: ContentMode = .fill
    @State private var image: NSImage?
    @State private var loaded = false
    @State private var representedPath: String?
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.sidebar
                if let image {
                    ZStack {
                        if contentMode == .fit {
                            Image(nsImage: image).resizable().scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .blur(radius: 24).overlay(.black.opacity(0.12))
                        }
                        Image(nsImage: image).resizable().aspectRatio(contentMode: contentMode)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .clipped().id(representedPath).transition(.opacity)
                }
                else if loaded { Image(systemName: "photo.badge.exclamationmark").foregroundStyle(Palette.muted).accessibilityLabel("Image unavailable") }
                else { RoundedRectangle(cornerRadius: 8).fill(Palette.line.opacity(0.6)).padding(10).accessibilityLabel("Loading image") }
            }
        }
        .animation(reducedMotion ? .easeOut(duration: 0.1) : Motion.fade, value: representedPath)
        .task(id: path) { loaded = false
            let result = await ImageCache.shared.image(path: path, pixels: pixels)
            guard !Task.isCancelled else { return }
            image = result; representedPath = path; loaded = true }
    }
}

private func eyebrow(_ title: String) -> some View { Text(title).font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.7).foregroundStyle(Palette.muted) }
func imageTitle(_ path: String) -> String {
    let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    return stem.replacingOccurrences(of: "^\\d+-", with: "", options: .regularExpression).replacingOccurrences(of: "-", with: " ").capitalized
}
