import Foundation

public struct Phase: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var startMinute: Int
    public var wallpapers: [String]
    public var audioPath: String
    public var youtubeURL: String
    public var audioSource: AudioSource

    public init(id: UUID = UUID(), name: String, startMinute: Int, wallpapers: [String] = [], audioPath: String = "", youtubeURL: String = "", audioSource: AudioSource = .local) {
        self.id = id
        self.name = name
        self.startMinute = startMinute
        self.wallpapers = wallpapers
        self.audioPath = audioPath
        self.youtubeURL = youtubeURL
        self.audioSource = audioSource
    }

    public var timeLabel: String { String(format: "%02d:%02d", startMinute / 60, startMinute % 60) }
}

public enum AudioSource: String, Codable, CaseIterable {
    case local, youtube, youtubeAudio
}

public enum LocalAudioLibrary {
    public static func paths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return paths.compactMap { path in
            guard path.hasPrefix("/") else { return nil }
            let normalized = URL(fileURLWithPath: path).standardizedFileURL.path
            return seen.insert(normalized).inserted ? normalized : nil
        }
    }
}

public struct AudioOverride: Equatable {
    public let path: String
    public let phaseID: UUID
    public let expiresAt: Date

    public init(path: String, phaseID: UUID, expiresAt: Date) {
        self.path = path
        self.phaseID = phaseID
        self.expiresAt = expiresAt
    }

    public func applies(to phaseID: UUID?, at date: Date) -> Bool {
        self.phaseID == phaseID && date < expiresAt
    }
}

public enum AppAppearance: String, Codable, CaseIterable {
    case system, light, dark
}

public struct Preferences: Codable, Equatable {
    public var phases: [Phase]
    public var enabled = false
    public var wallpaperEnabled = true
    public var audioEnabled = false
    public var volume: Double = 0.35
    public var libraryFolder = ""
    public var audioLibraryPaths: [String] = []
    public var appearance: AppAppearance = .system

    public init(phases: [Phase] = [
        Phase(name: "Morning", startMinute: 360),
        Phase(name: "Noon", startMinute: 720),
        Phase(name: "Night", startMinute: 1080)
    ]) { self.phases = phases }

    private enum CodingKeys: String, CodingKey {
        case phases, enabled, wallpaperEnabled, audioEnabled, volume, libraryFolder, audioLibraryPaths, appearance
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        phases = try values.decode([Phase].self, forKey: .phases)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        wallpaperEnabled = try values.decode(Bool.self, forKey: .wallpaperEnabled)
        audioEnabled = try values.decode(Bool.self, forKey: .audioEnabled)
        volume = try values.decode(Double.self, forKey: .volume)
        libraryFolder = try values.decode(String.self, forKey: .libraryFolder)
        audioLibraryPaths = LocalAudioLibrary.paths(try values.decodeIfPresent([String].self, forKey: .audioLibraryPaths) ?? phases.map(\.audioPath))
        appearance = try values.decodeIfPresent(AppAppearance.self, forKey: .appearance) ?? .system
    }

    public func validate() throws {
        guard !phases.isEmpty else { throw ValidationError("Keep at least one phase.") }
        guard Set(phases.map(\.id)).count == phases.count else { throw ValidationError("Each phase must have a unique identity.") }
        guard phases.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw ValidationError("Give every phase a name.") }
        guard phases.allSatisfy({ (0..<1440).contains($0.startMinute) }) else { throw ValidationError("Phase times must fall within a day.") }
        guard Set(phases.map(\.startMinute)).count == phases.count else { throw ValidationError("Each phase needs a different start time.") }
        guard volume.isFinite && (0...1).contains(volume) else { throw ValidationError("Volume must be between 0 and 100 percent.") }
    }
}

public struct ValidationError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public enum Schedule {
    public static func phase(at date: Date, phases: [Phase], calendar: Calendar = .current) -> Phase? {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let sorted = phases.sorted { $0.startMinute < $1.startMinute }
        return sorted.last(where: { $0.startMinute <= minute }) ?? sorted.last
    }

    public static func nextBoundary(after date: Date, phases: [Phase], calendar: Calendar = .current) -> Date? {
        phases.compactMap { phase in
            calendar.nextDate(after: date, matching: DateComponents(hour: phase.startMinute / 60, minute: phase.startMinute % 60, second: 0), matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
        }.min()
    }

    public static func previousWallpaper(in paths: [String], current: String?) -> String? {
        guard !paths.isEmpty else { return nil }
        guard let current, let index = paths.firstIndex(of: current) else { return paths.last }
        return paths[(index + paths.count - 1) % paths.count]
    }

    public static func nextWallpaper(in paths: [String], current: String?) -> String? {
        guard !paths.isEmpty else { return nil }
        guard let current, let index = paths.firstIndex(of: current) else { return paths.first }
        return paths[(index + 1) % paths.count]
    }
}

public enum YouTube {
    public static func videoID(from value: String) -> String? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", let host = url.host?.lowercased(),
              ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "www.youtu.be"].contains(host)
        else { return nil }
        let segments = url.pathComponents.filter { $0 != "/" }
        let candidate: String?
        if host == "youtu.be" || host == "www.youtu.be" { candidate = segments.first }
        else if ["embed", "shorts", "live"].contains(segments.first ?? "") { candidate = segments.dropFirst().first }
        else if url.path == "/watch" { candidate = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "v" })?.value }
        else { candidate = nil }
        guard let candidate, candidate.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        return candidate
    }
}

public enum PreferenceFile {
    public static func load(from url: URL) throws -> Preferences {
        let value = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: url))
        try value.validate()
        return value
    }
    public static func save(_ value: Preferences, to url: URL) throws {
        try value.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url, options: .atomic)
    }
}
