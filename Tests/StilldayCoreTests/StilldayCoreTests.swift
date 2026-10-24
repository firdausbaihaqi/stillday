import Foundation
import StilldayCore

struct StilldayCoreTests {
    let phases = Preferences().phases
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }
    func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: hour, minute: minute))!
    }
    func testScheduleWrapsMidnightAndSwitchesAtExactBoundary() {
        for (hour, minute, expected) in [(0, 0, "Night"), (5, 59, "Night"), (6, 0, "Morning"), (11, 59, "Morning"), (12, 0, "Noon"), (17, 59, "Noon"), (18, 0, "Night"), (23, 59, "Night")] {
            expectEqual(Schedule.phase(at: date(hour, minute), phases: phases, calendar: calendar)?.name, expected)
        }
    }
    func testCustomPhasesAndUnsortedInput() {
        let custom = [Phase(name: "Rest", startMinute: 1300), Phase(name: "Work", startMinute: 540)]
        expectEqual(Schedule.phase(at: date(10), phases: custom, calendar: calendar)?.name, "Work")
        expectEqual(Schedule.phase(at: date(3), phases: custom, calendar: calendar)?.name, "Rest")
    }
    func testNextBoundaryDoesNotRepeatCurrentBoundary() {
        expectEqual(Schedule.nextBoundary(after: date(6), phases: phases, calendar: calendar), date(12))
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date(6))!
        expectEqual(Schedule.nextBoundary(after: date(23), phases: phases, calendar: calendar), tomorrow)
    }
    func testDaylightSavingBoundaryRemainsInFuture() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let before = cal.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 59))!
        let next = Schedule.nextBoundary(after: before, phases: [Phase(name: "Dawn", startMinute: 150)], calendar: cal)
        expectNotNil(next)
        expectGreaterThan(next!, before)
    }
    func testEmptyScheduleAndWallpaperRotation() {
        expectNil(Schedule.phase(at: date(1), phases: [], calendar: calendar))
        expectNil(Schedule.nextBoundary(after: date(1), phases: [], calendar: calendar))
        expectNil(Schedule.nextWallpaper(in: [], current: nil))
        expectEqual(Schedule.nextWallpaper(in: ["a", "b"], current: "b"), "a")
        expectEqual(Schedule.nextWallpaper(in: ["a", "b"], current: "removed"), "a")
    }
    func testInvalidPreferencesAreRejected() {
        var value = Preferences()
        value.phases[1].startMinute = value.phases[0].startMinute
        expectThrows { try value.validate() }
        value = Preferences(); value.phases[0].name = "   "
        expectThrows { try value.validate() }
        value = Preferences(); value.phases[0].startMinute = 1440
        expectThrows { try value.validate() }
        value = Preferences(); value.phases = []
        expectThrows { try value.validate() }
        value = Preferences(); value.volume = .nan
        expectThrows { try value.validate() }
    }
    func testYouTubeLinksAreValidatedBeforeEmbedding() {
        for link in ["https://www.youtube.com/watch?v=jfKfPfyJRdk", "https://youtu.be/jfKfPfyJRdk?t=4", "https://youtube.com/live/jfKfPfyJRdk", "https://youtube.com/shorts/jfKfPfyJRdk"] {
            expectEqual(YouTube.videoID(from: link), "jfKfPfyJRdk")
        }
        for link in ["javascript:alert(1)", "https://youtube.com.attacker.test/watch?v=jfKfPfyJRdk", "http://youtube.com/watch?v=jfKfPfyJRdk", "https://youtube.com/watch?v=<script>", "https://youtube.com/playlist?list=123"] {
            expectNil(YouTube.videoID(from: link))
        }
    }
    func testPreferenceRoundTripAndCorruptFilePreservation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("settings.json")
        var value = Preferences(); value.phases[0].audioPath = "/a track.m4a"
        try PreferenceFile.save(value, to: url)
        expectEqual(try PreferenceFile.load(from: url), value)
        let corrupted = Data("invalid json".utf8)
        try corrupted.write(to: url)
        expectThrows { _ = try PreferenceFile.load(from: url) }
        expectEqual(try Data(contentsOf: url), corrupted)
    }
}


private var checks = 0
private var failures = 0
private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if actual != expected { failures += 1; print("FAIL \(file):\(line) expected \(expected), got \(actual)") }
}
private func expectNil<T>(_ actual: T?, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if actual != nil { failures += 1; print("FAIL \(file):\(line) expected nil") }
}
private func expectNotNil<T>(_ actual: T?, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if actual == nil { failures += 1; print("FAIL \(file):\(line) expected a value") }
}
private func expectGreaterThan<T: Comparable>(_ actual: T, _ minimum: T, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    if actual <= minimum { failures += 1; print("FAIL \(file):\(line) expected a future boundary") }
}
private func expectThrows(_ action: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    do { try action(); failures += 1; print("FAIL \(file):\(line) expected an error") } catch {}
}

@main
struct RunChecks {
    static func main() throws {
        let tests = StilldayCoreTests()
        tests.testScheduleWrapsMidnightAndSwitchesAtExactBoundary()
        tests.testCustomPhasesAndUnsortedInput()
        tests.testNextBoundaryDoesNotRepeatCurrentBoundary()
        tests.testDaylightSavingBoundaryRemainsInFuture()
        tests.testEmptyScheduleAndWallpaperRotation()
        tests.testInvalidPreferencesAreRejected()
        tests.testYouTubeLinksAreValidatedBeforeEmbedding()
        try tests.testPreferenceRoundTripAndCorruptFilePreservation()
        print("\(checks - failures)/\(checks) regression checks passed")
        if failures > 0 { exit(1) }
    }
}
