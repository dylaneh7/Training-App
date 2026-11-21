import Foundation
import Combine

/// Running goals, shoes, races, and session notes stay in an on-device,
/// per-install logbook. No account upload or health sharing is implied.
struct IMUNRunningShoe: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var startingMiles: Double = 0
    var retired = false
    var createdAt = Date()
}

struct IMUNRunningRace: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var on: Date
    var distanceMeters: Double
    var goalSeconds: Double? = nil
}

struct IMUNRunningRunNote: Codable, Hashable {
    var shoeID: UUID? = nil
    var effort: Int? = nil
    var notes = ""
    var fueling = ""
    var hydrationOunces: Double? = nil
    var temperatureF: Double? = nil
    var weatherNotes = ""
    var updatedAt = Date()
}

struct IMUNRunningLogbookData: Codable {
    var goalMilesPerWeek: Double? = nil
    var goalRunsPerWeek: Int? = nil
    var shoes: [IMUNRunningShoe] = []
    var races: [IMUNRunningRace] = []
    var notes: [String: IMUNRunningRunNote] = [:]
}

/// Native, explicit-write persistence. A manual log entry never edits the
/// source workout or claims to have been measured by a wearable.
@MainActor
final class IMUNRunningLogbook: ObservableObject {
    static let shared = IMUNRunningLogbook()
    @Published private(set) var data = IMUNRunningLogbookData()
    @Published private(set) var lastError: String? = nil

    private let filename = "imun-running-logbook-v1.json"

    private init() {
        guard let file = fileURL(),
              let saved = try? Data(contentsOf: file),
              let parsed = try? JSONDecoder().decode(IMUNRunningLogbookData.self,
                                                      from: saved)
        else { return }
        data = parsed
    }

    private func fileURL() -> URL? {
        guard let folder = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder,
                withIntermediateDirectories: true)
        } catch { return nil }
        return folder.appendingPathComponent(filename)
    }

    private func store() {
        guard let file = fileURL() else {
            lastError = "Local running journal storage is unavailable."
            return
        }
        do {
            let saved = try JSONEncoder().encode(data)
            try saved.write(to: file, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Running journal could not save: " +
                error.localizedDescription
        }
    }

    func setGoal(miles: Double?, runs: Int?) {
        guard miles.map({ $0.isFinite && (1...250).contains($0) }) ?? true,
              runs.map({ (1...21).contains($0) }) ?? true else { return }
        data.goalMilesPerWeek = miles
        data.goalRunsPerWeek = runs
        store()
    }

    func addShoe(_ name: String, startingMiles: Double = 0) {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...65).contains(text.count),
              startingMiles.isFinite,
              (0...10000).contains(startingMiles) else { return }
        data.shoes.append(IMUNRunningShoe(name: text,
                                          startingMiles: startingMiles))
        store()
    }

    func retireShoe(_ id: UUID, retired: Bool) {
        guard let index = data.shoes.firstIndex(where: { $0.id == id })
        else { return }
        data.shoes[index].retired = retired
        store()
    }

    func removeShoe(_ id: UUID) {
        // Annotations are historical records; deleting a shoe removes its
        // assignments instead of retaining dangling IDs.
        data.shoes.removeAll { $0.id == id }
        for key in Array(data.notes.keys) {
            if data.notes[key]?.shoeID == id {
                data.notes[key]?.shoeID = nil
            }
        }
        store()
    }

    func addRace(name: String, date: Date, meters: Double,
                 goalSeconds: Double?) {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty && title.count <= 80,
              (400...200000).contains(meters),
              meters.isFinite,
              goalSeconds.map({ (60...200000).contains($0) && $0.isFinite }) ?? true
        else { return }
        data.races.append(IMUNRunningRace(
            name: title, on: date, distanceMeters: meters,
            goalSeconds: goalSeconds))
        data.races.sort { $0.on < $1.on }
        store()
    }

    func removeRace(_ id: UUID) {
        data.races.removeAll { $0.id == id }
        store()
    }

    func note(for runID: String) -> IMUNRunningRunNote {
        data.notes[runID] ?? IMUNRunningRunNote()
    }

    func setNote(_ note: IMUNRunningRunNote, for runID: String) {
        guard !runID.isEmpty && runID.count < 300 else { return }
        var cleaned = note
        cleaned.notes = String(note.notes.prefix(3000))
        cleaned.fueling = String(note.fueling.prefix(1500))
        cleaned.weatherNotes = String(note.weatherNotes.prefix(500))
        cleaned.effort = note.effort.flatMap { (1...10).contains($0) ? $0 : nil }
        cleaned.hydrationOunces = note.hydrationOunces.flatMap {
            $0.isFinite && (0...1000).contains($0) ? $0 : nil
        }
        cleaned.temperatureF = note.temperatureF.flatMap {
            $0.isFinite && (-80...160).contains($0) ? $0 : nil
        }
        if let shoe = cleaned.shoeID,
           !data.shoes.contains(where: { $0.id == shoe }) {
            cleaned.shoeID = nil
        }
        cleaned.updatedAt = Date()
        data.notes[runID] = cleaned
        store()
    }

    /// Run attribution must use de-duplicated workouts so Garmin/HealthKit
    /// copies of one workout do not double-count shoe distance.
    func miles(for shoe: IMUNRunningShoe,
               in history: [HCProgressRun]) -> Double {
        let logged = IMUNRunningIntelligence.uniqueRuns(history).reduce(0.0) {
            sum, run in
            guard data.notes[run.id]?.shoeID == shoe.id,
                  let meters = run.distanceMeters, meters > 0 else {
                return sum
            }
            return sum + meters / IMUNRunningIntelligence.mile
        }
        return shoe.startingMiles + logged
    }

    /// Manual temperature notes contextualize measured pace; do not treat
    /// observational comparisons as validated environmental corrections.
    func conditionsComparison(_ run: HCProgressRun,
                              history: [HCProgressRun]) -> String? {
        guard let temperature = data.notes[run.id]?.temperatureF,
              let distance = run.distanceMeters,
              distance >= 1000,
              let thisPace = IMUNRunningIntelligence.pacePerMile(run)
        else { return nil }
        let peers = IMUNRunningIntelligence.uniqueRuns(history).filter {
            guard $0.id != run.id,
                  let meters = $0.distanceMeters,
                  abs(meters - distance) / distance <= 0.12,
                  data.notes[$0.id]?.temperatureF != nil else { return false }
            return IMUNRunningIntelligence.pacePerMile($0) != nil
        }
        guard peers.count >= 2 else { return nil }
        let sample = Array(peers.prefix(10))
        let temperatures = sample.compactMap {
            data.notes[$0.id]?.temperatureF
        }
        let paces = sample.compactMap {
            IMUNRunningIntelligence.pacePerMile($0)
        }
        guard temperatures.count >= 2 && paces.count >= 2 else {
            return nil
        }
        let pastTemperature = temperatures.reduce(0,+) /
            Double(temperatures.count)
        let pastPace = paces.reduce(0,+) / Double(paces.count)
        let tempDifference = temperature - pastTemperature
        let paceDifference = thisPace - pastPace
        return String(format:
            "Your manually logged temperature was %.0f °F versus %.0f °F across %d similarly long runs (%+.0f °F). Recorded pace differed by %+.0f sec/mile. Workout effort, wind, humidity, hills, fueling and sensors may confound this comparison; temperature is not proven to have caused the change.",
            temperature, pastTemperature, sample.count,
            tempDifference, paceDifference)
    }

    /// Only compact goal/race metadata, not notes or journal text, is eligible
    /// for an opt-in IsAIah message. The user must still tap Send.
    func coachingContext(for run: HCProgressRun,
                         history: [HCProgressRun]) -> String {
        var result: [String] = []
        if let target = data.goalMilesPerWeek {
            result.append(String(format:
                "User-selected weekly running goal: %.1f mi.", target))
        }
        if let target = data.goalRunsPerWeek {
            result.append("User-selected run frequency goal: \(target) runs/week.")
        }
        if let race = data.races.filter({ $0.on >= Date() })
            .sorted(by: { $0.on < $1.on }).first {
            result.append(String(format:
                "Upcoming recorded race: %@ on %@, %.1f km.",
                race.name, race.on.formatted(date: .abbreviated, time: .omitted),
                race.distanceMeters / 1000))
        }
        if let temp = conditionsComparison(run, history: history) {
            result.append(temp)
        }
        return result.joined(separator: "\n")
    }

    func goalStatus(in runs: [HCProgressRun],
                    now: Date = Date()) -> [String] {
        let load = IMUNRunningIntelligence.weeklyLoad(runs, now: now)
        var result: [String] = []
        if let target = data.goalMilesPerWeek {
            result.append(String(format:
                "%.1f of %.1f weekly miles recorded (%.0f%%).",
                load.recent7Miles, target,
                min(999, 100 * load.recent7Miles / max(0.1, target))))
        }
        if let target = data.goalRunsPerWeek {
            result.append("\(load.distinctRuns7) of \(target) weekly runs recorded.")
        }
        return result
    }

    /// A day with a scheduled running workout and a completed run is
    /// considered matched. Intervals and prescribed intensities are *not*
    /// presumed complete from a generic Garmin/HealthKit upload.
    func scheduleAdherence(_ planned: [HCPlannedSession],
                           runs: [HCProgressRun],
                           referenceDate: Date = Date())
        -> (matched: Int, planned: Int)? {
        let start = Calendar.current.date(byAdding: .day, value: -28,
                                          to: referenceDate) ?? referenceDate
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: referenceDate)
        let since = formatter.string(from: start)
        let scheduled = planned.filter {
            $0.kind == "run" && $0.date >= since && $0.date <= today
        }
        guard !scheduled.isEmpty else { return nil }
        let completedDates = Set(
            IMUNRunningIntelligence.uniqueRuns(runs).map(\.date))
        let matches = scheduled.filter {
            $0.completed || completedDates.contains($0.date)
        }.count
        return (matches, scheduled.count)
    }
}
