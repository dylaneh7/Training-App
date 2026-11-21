import Foundation

/// Running Lab uses recorded, source-labeled data. It is intentionally
/// separate from IsAIah's language layer: calculations must be reproducible.
struct IMUNRunningObservation: Identifiable {
    let id: String
    let title: String
    let detail: String
}

struct IMUNRunningZone: Identifiable {
    let index: Int
    let lowBPM: Int
    let highBPM: Int?
    let seconds: Double
    var id: Int { index }
    var title: String { "Z" + String(index) }
}

struct IMUNRunningBestEffort: Identifiable {
    let distanceName: String
    let targetMeters: Double
    let timeSeconds: Double
    let date: String
    let source: String
    var id: String { distanceName }
}

struct IMUNRunningLoad {
    let recent7Miles: Double
    let prior21WeeklyMiles: Double?
    let recent28Miles: Double
    let longRunShare: Double?
    let distinctRuns7: Int
    let comparisons: Int
}

enum IMUNRunningIntelligence {
    static let mile = 1609.344

    static func metric(_ run: HCProgressRun, kind: String) -> [HCRunSensorReading] {
        (run.sensorSeries ?? []).filter { point in
            guard point.kind == kind, point.value.isFinite else { return false }
            // Grade, environmental temperature and altitude may legitimately
            // be zero or negative; do not drop descents or cold-weather data.
            if ["runningSourceGrade", "runningSourceTemperature",
                "runningAltitude"].contains(kind) { return true }
            return point.value > 0
        }.sorted { $0.at < $1.at }
    }

    static func pacePerMile(_ run: HCProgressRun) -> Double? {
        guard let distance = run.distanceMeters, distance >= 200,
              let seconds = run.durationSeconds, seconds > 0 else { return nil }
        return seconds * mile / distance
    }

    static func formatPace(_ seconds: Double?) -> String {
        guard let seconds, seconds.isFinite,
              seconds > 0 && seconds < 36000 else { return "—" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Multiple apps can publish the same run. Dedupe only when a recording
    /// is near-identical in date, distance and duration, or shares an explicit
    /// workout start timestamp. Never add duplicate provider miles together.
    static func uniqueRuns(_ input: [HCProgressRun]) -> [HCProgressRun] {
        let sorted = input.sorted {
            let a = $0.startedAt ?? .distantPast
            let b = $1.startedAt ?? .distantPast
            if a != b { return a > b }
            return $0.date > $1.date
        }
        var chosen: [HCProgressRun] = []
        for run in sorted {
            let duplicate = chosen.contains { other in
                guard other.date == run.date,
                      let a = other.distanceMeters, let b = run.distanceMeters,
                      let ta = other.durationSeconds, let tb = run.durationSeconds,
                      a > 0, b > 0, ta > 0, tb > 0 else { return false }
                let closeDistance = abs(a - b) / max(a, b) < 0.025
                let closeTime = abs(ta - tb) / max(ta, tb) < 0.025
                let sameStart: Bool
                if let left = other.startedAt, let right = run.startedAt {
                    sameStart = abs(left.timeIntervalSince(right)) < 180
                } else {
                    sameStart = true
                }
                return closeDistance && closeTime && sameStart
            }
            if !duplicate { chosen.append(run) }
        }
        return chosen
    }

    static func weeklyLoad(_ runs: [HCProgressRun],
                           now: Date = Date()) -> IMUNRunningLoad {
        let calendar = Calendar.current
        let start7 = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let start28 = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        let unique = uniqueRuns(runs)
        let values: [(at: Date, meters: Double)] = unique.compactMap { run in
            guard let distance = run.distanceMeters, distance > 0 else { return nil }
            let stamp = run.startedAt ?? day(run.date)
            guard let stamp, stamp <= now else { return nil }
            return (stamp, distance)
        }
        let recent = values.filter { $0.at >= start7 }
        let all28 = values.filter { $0.at >= start28 }
        let earlier21 = values.filter { $0.at >= start28 && $0.at < start7 }
        let miles7 = recent.reduce(0.0) { $0 + $1.meters } / mile
        let miles28 = all28.reduce(0.0) { $0 + $1.meters } / mile
        let olderWeekly: Double? = earlier21.isEmpty ? nil :
            earlier21.reduce(0.0) { $0 + $1.meters } / (3 * mile)
        let largest = recent.map { $0.meters }.max()
        let totalMeters = recent.reduce(0.0) { $0 + $1.meters }
        return IMUNRunningLoad(
            recent7Miles: miles7, prior21WeeklyMiles: olderWeekly,
            recent28Miles: miles28,
            longRunShare: totalMeters > 0 ? largest.map { $0 / totalMeters } : nil,
            distinctRuns7: recent.count, comparisons: earlier21.count)
    }

    private static func day(_ raw: String) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        parser.timeZone = .current
        return parser.date(from: raw)
    }

    /// Best *whole recorded run* in a distance band, not a Strava-style
    /// rolling split, race personal record, or GPS-estimated best effort.
    static func bestEfforts(_ input: [HCProgressRun]) -> [IMUNRunningBestEffort] {
        let benchmarks: [(String, Double)] = [
            ("1 mile", mile), ("5K", 5000), ("10K", 10000),
            ("Half marathon", 21097.5), ("Marathon", 42195)
        ]
        let valid = uniqueRuns(input)
        return benchmarks.compactMap { label, target in
            let close = valid.filter { run in
                guard let distance = run.distanceMeters,
                      let duration = run.durationSeconds,
                      duration > 0 else { return false }
                return distance >= target * 0.98 && distance <= target * 1.04
            }
            guard let winner = close.min(by: {
                ($0.durationSeconds ?? .infinity) <
                ($1.durationSeconds ?? .infinity)
            }), let time = winner.durationSeconds else { return nil }
            return IMUNRunningBestEffort(distanceName: label,
                targetMeters: target, timeSeconds: time,
                date: winner.date, source: winner.source)
        }
    }

    static func heartRateZones(_ run: HCProgressRun,
                               maxBPM: Int) -> [IMUNRunningZone] {
        guard (120...240).contains(maxBPM),
              run.heartRateTrace.count >= 4 else { return [] }
        let samples = run.heartRateTrace.filter {
            $0.bpm.isFinite && $0.bpm >= 35 && $0.bpm <= 240
        }.sorted { $0.at < $1.at }
        var durations = Array(repeating: 0.0, count: 5)
        guard samples.count >= 2 else { return [] }
        for index in 0..<(samples.count - 1) {
            let dt = samples[index + 1].at.timeIntervalSince(samples[index].at)
            guard dt > 0, dt <= 75 else { continue }
            let percent = samples[index].bpm / Double(maxBPM)
            let zone = percent < 0.60 ? 0 :
                percent < 0.70 ? 1 :
                percent < 0.80 ? 2 :
                percent < 0.90 ? 3 : 4
            durations[zone] += dt
        }
        return (0..<5).map { index in
            IMUNRunningZone(index: index + 1,
                lowBPM: Int((Double(maxBPM) * ([0.0,0.60,0.70,0.80,0.90][index])).rounded()),
                highBPM: index == 4 ? nil :
                    Int((Double(maxBPM) * ([0.60,0.70,0.80,0.90][index])).rounded()),
                seconds: durations[index])
        }
    }

    private static func median(_ items: [Double]) -> Double? {
        let sorted = items.sorted()
        guard !sorted.isEmpty else { return nil }
        let half = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ?
            (sorted[half - 1] + sorted[half]) / 2 : sorted[half]
    }

    /// Pairs measured run speed with measured HR from the same session.
    /// An increasing HR trend at roughly stable speed is observational only.
    private static func aerobicDriftNote(_ run: HCProgressRun) -> String? {
        let speed = metric(run, kind: "runningSpeed")
            .filter { (1.2...9).contains($0.value) }
        let hr = run.heartRateTrace.sorted { $0.at < $1.at }
        guard speed.count >= 20, hr.count >= 20,
              let start = run.startedAt, let end = run.endedAt,
              end.timeIntervalSince(start) >= 25 * 60 else { return nil }
        let midpoint = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
        var first: [(speed: Double, hr: Double)] = []
        var last: [(speed: Double, hr: Double)] = []
        var cursor = 0
        for sample in speed {
            while cursor + 1 < hr.count &&
                  hr[cursor + 1].at <= sample.at { cursor += 1 }
            let nearby = [hr[cursor],
                          hr[min(cursor + 1, hr.count - 1)]].min {
                abs($0.at.timeIntervalSince(sample.at)) <
                abs($1.at.timeIntervalSince(sample.at))
            }
            guard let heart = nearby, heart.bpm >= 55,
                  abs(heart.at.timeIntervalSince(sample.at)) <= 30 else { continue }
            if sample.at < midpoint {
                first.append((sample.value, heart.bpm))
            } else {
                last.append((sample.value, heart.bpm))
            }
        }
        guard first.count >= 8, last.count >= 8 else { return nil }
        let aSpeed = first.reduce(0.0) { $0 + $1.speed } / Double(first.count)
        let bSpeed = last.reduce(0.0) { $0 + $1.speed } / Double(last.count)
        guard aSpeed > 0, abs(bSpeed / aSpeed - 1) <= 0.10 else { return nil }
        let aHR = first.reduce(0.0) { $0 + $1.hr } / Double(first.count)
        let bHR = last.reduce(0.0) { $0 + $1.hr } / Double(last.count)
        let change = bHR - aHR
        guard abs(change) >= 3 else { return "Heart rate was relatively stable at similar recorded speeds." }
        return String(format: "At roughly similar recorded speeds, mean heart rate was %.0f bpm %@ in the second half. Terrain, weather, fatigue and sensor error can all affect this comparison.",
                      abs(change), change > 0 ? "higher" : "lower")
    }

    static func sessionInsights(_ run: HCProgressRun,
                                history: [HCProgressRun]) -> [IMUNRunningObservation] {
        var result: [IMUNRunningObservation] = []
        if let drift = aerobicDriftNote(run) {
            result.append(.init(id: "drift", title: "Heart-rate response",
                                detail: drift))
        }
        if let distance = run.distanceMeters, distance >= 1000,
           let pace = pacePerMile(run) {
            let prior = uniqueRuns(history).filter { candidate in
                guard candidate.id != run.id,
                      candidate.date < run.date,
                      let priorDistance = candidate.distanceMeters,
                      priorDistance > 0 else { return false }
                return abs(priorDistance - distance) / distance < 0.12 &&
                    pacePerMile(candidate) != nil
            }.sorted { $0.date > $1.date }
            if let closest = prior.first,
               let earlier = pacePerMile(closest) {
                let delta = pace - earlier
                result.append(.init(id: "pace-comparison",
                    title: "Comparable distance",
                    detail: String(format:
                        "Average pace was %.0f sec/mi %@ than %@ on %@. Conditions and effort may differ.",
                        abs(delta), delta <= 0 ? "faster" : "slower",
                        closest.source, closest.date)))
            }
        }
        let speed = metric(run, kind: "runningSpeed").map(\.value)
        if speed.count >= 12 {
            let mean = speed.reduce(0, +) / Double(speed.count)
            if mean > 0 {
                let variance = speed.reduce(0.0) { $0 + pow($1 - mean, 2) } /
                    Double(speed.count)
                result.append(.init(id: "speed-variability",
                    title: "Speed consistency",
                    detail: String(format:
                        "Recorded speed varied by %.0f%% (coefficient of variation). Intervals, hills, stops and GPS noise can all produce variation.",
                        100 * sqrt(variance) / mean)))
            }
        }
        let prior = uniqueRuns(history).filter {
            $0.date < run.date && $0.averageCadenceSPM != nil &&
            $0.distanceMeters != nil
        }.prefix(12)
        if let cadence = run.averageCadenceSPM,
           let baseline = median(prior.compactMap(\.averageCadenceSPM)) {
            result.append(.init(id: "cadence",
                title: "Your cadence baseline",
                detail: String(format:
                    "Current recorded cadence %.0f spm versus %.0f spm across recent available runs. Different speeds and terrain can explain the difference; there is no universal cadence target.",
                    cadence, baseline)))
        }
        let gps = run.routeMileSplits ?? []
        if gps.count >= 2 {
            let first = gps.prefix(gps.count / 2)
            let later = gps.suffix(gps.count - first.count)
            let one = first.reduce(0.0) { $0 + $1.elapsedSeconds } / Double(first.count)
            let two = later.reduce(0.0) { $0 + $1.elapsedSeconds } / Double(later.count)
            result.append(.init(id: "gps-splits",
                title: "GPS-derived pacing",
                detail: String(format:
                    "Estimated split pace was %.0f sec/mile %@ in the latter route miles; approximate GPS splits, not recorded lap events.",
                    abs(two - one), two <= one ? "faster" : "slower")))
        }
        if run.sensorSeries?.isEmpty != false {
            result.append(.init(id: "coverage", title: "Running dynamics",
                detail: "No time-resolved dynamics have been shared for this run. iMun won't infer cadence, ground-contact time, or running power from unrelated signals."))
        } else {
            let kinds = Set((run.sensorSeries ?? []).map(\.kind))
            result.append(.init(id: "coverage", title: "Running dynamics",
                detail: "\(kinds.count) source-recorded dynamic signal types available. Values are interpreted against your own comparable history rather than universal form targets."))
        }
        return result
    }

    static func coachContext(for run: HCProgressRun,
                             history: [HCProgressRun],
                             maximumBPM: Int) -> String {
        let load = weeklyLoad(history)
        var lines = [
            "RUNNING LAB / ANALYSIS REQUEST — use only evidence listed below.",
            "Source: \(run.source); date \(run.date); run ID \(run.id).",
            "The runner explicitly opened this run for coaching. Do not assume absent metrics were measured.",
            "Measured distance: \(run.distanceMeters.map { String(format:"%.1f m",$0) } ?? "unknown"); duration: \(run.durationSeconds.map { String(format:"%.0f sec",$0) } ?? "unknown"); calculated whole-run pace: \(formatPace(pacePerMile(run))) min/mile.",
            "Recorded HR: average \(run.averageBPM.map { String(format:"%.0f",$0) } ?? "unknown") bpm, max \(run.maxBPM.map { String(format:"%.0f",$0) } ?? "unknown") bpm.",
            "Power \(run.averagePowerWatts.map { String(format:"%.0f W",$0) } ?? "missing"), cadence \(run.averageCadenceSPM.map { String(format:"%.0f spm",$0) } ?? "missing"), stride \(run.averageStrideLengthMeters.map { String(format:"%.2f m",$0) } ?? "missing"), ground contact \(run.averageGroundContactTimeMS.map { String(format:"%.0f ms",$0) } ?? "missing"), vertical oscillation \(run.averageVerticalOscillationCM.map { String(format:"%.1f cm",$0) } ?? "missing").",
            String(format: "Unique running distance past 7 days %.1f mi, past 28 days %.1f mi; duplicates are excluded where attributable.",load.recent7Miles,load.recent28Miles),
            "Observed session insights: " + sessionInsights(run, history: history).map {
                "\($0.title): \($0.detail)"
            }.joined(separator: " | "),
            "Do not prescribe a cadence of 180, diagnose injury, infer exact biomechanics, or make automated plan changes. Compare sources and similarly paced sessions; label uncertainty."
        ]
        let zones = heartRateZones(run, maxBPM: maximumBPM)
        if !zones.isEmpty {
            lines.append("HR zone estimates use explicitly configured maximum HR \(maximumBPM) bpm, not age-based inference: " +
                zones.map { "\($0.title): \(Int($0.seconds)) s" }.joined(separator: ", "))
        }
        return lines.joined(separator: "\n")
    }
}
