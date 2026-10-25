import Foundation
import StilldayCore

/// Resolves once, then exits. AVFoundation owns playback without a browser or helper process.
@MainActor
final class YouTubeAudioResolver {
    struct Stream: Decodable {
        let url: URL
        let title: String
    }

    private var process: Process?
    private var requestID: UUID?
    private var timeout: Task<Void, Never>?

    func resolve(videoID: String) async throws -> Stream {
        let locations = ["/opt/homebrew/bin/yt-dlp", "/usr/local/bin/yt-dlp"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/yt-dlp" }
        guard let executable = locations.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ValidationError("YouTube audio needs yt-dlp. Install it with brew install yt-dlp, then switch sound on again. Local audio and the YouTube player work without it.")
        }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Stillday-stream-\(id)")
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    let output = directory.appendingPathComponent("stream.json")
                    FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600])
                    let handle = try FileHandle(forWritingTo: output)
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = ["--ignore-config", "--no-playlist", "--no-progress", "--no-warnings", "--skip-download", "--socket-timeout", "15", "--retries", "1", "--extractor-retries", "1", "--format", "bestaudio[protocol^=m3u8]/bestaudio[ext=m4a]/bestaudio[acodec^=mp4a]", "--print", "{\"url\":%(url)j,\"title\":%(title)j}", "--", "https://www.youtube.com/watch?v=\(videoID)"]
                    var environment = ProcessInfo.processInfo.environment
                    // Finder launches have a small PATH; include standard Homebrew runtimes.
                    environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
                    process.environment = environment
                    process.standardInput = FileHandle.nullDevice
                    process.standardOutput = handle
                    process.standardError = FileHandle.nullDevice
                    self.process = process
                    self.requestID = id
                    process.terminationHandler = { [self] completed in
                        Task { @MainActor in
                            try? handle.close()
                            defer { try? FileManager.default.removeItem(at: directory) }
                            let cancelled = self.requestID != id
                            if !cancelled {
                                self.timeout?.cancel(); self.timeout = nil
                                self.process = nil; self.requestID = nil
                            }
                            guard !cancelled else { continuation.resume(throwing: CancellationError()); return }
                            guard completed.terminationStatus == 0 else {
                                continuation.resume(throwing: ValidationError("Could not resolve YouTube audio. Try another public video, update yt-dlp, or use the YouTube player. Restricted videos and some live streams may be unavailable.")); return
                            }
                            do {
                                let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
                                guard let size = attributes[.size] as? NSNumber, size.intValue < 131_072 else { throw ValidationError("The YouTube stream response was too large.") }
                                let stream = try JSONDecoder().decode(Stream.self, from: Data(contentsOf: output))
                                guard stream.url.scheme == "https", stream.url.host != nil else { throw ValidationError("YouTube did not return a secure audio stream.") }
                                continuation.resume(returning: stream)
                            } catch { continuation.resume(throwing: error) }
                        }
                    }
                    do { try process.run() }
                    catch {
                        try? handle.close()
                        self.process = nil; self.requestID = nil
                        throw error
                    }
                    timeout = Task { [weak self] in
                        do { try await Task.sleep(for: .seconds(60)) } catch { return }
                        guard self?.requestID == id else { return }
                        self?.process?.terminate()
                    }
                } catch {
                    try? FileManager.default.removeItem(at: directory)
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancel(request: id) }
        }
    }

    private func cancel(request id: UUID) {
        guard requestID == id else { return }
        requestID = nil
        timeout?.cancel(); timeout = nil
        process?.terminate(); process = nil
    }
}
