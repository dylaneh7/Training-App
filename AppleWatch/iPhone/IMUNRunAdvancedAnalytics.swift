import Foundation

/// Analysis is derived from measurements and preserves uncertainty.
/// These structs contain no account identifiers or remote credentials.
struct IMUNRunBestSegment: Identifiable {
    let distanceMeters: Double
    let elapsedSeconds: Double
    let start: Date
    let end: Date
    let source: String
    var id: Int { Int(distanceMeters) }
    var distanceLabel: String {
        switch distanceMeters {
        case 400: return "400 m"
        case 1000: return "1 km"
        case 1609.344: return "1 mile"
        case 5000: return "5 km"
        case 10000: return "10 km"
        default: return "\(Int(distanceMeters)) m"
        }
    }
}

struct IMUNRunSurge: Identifiable {
    let start: Date
    let end: Date
    let meanSpeedMPS: Double
    let baselineSpeedMPS: Double
    var id: Date { start }
    var durationSeconds: Double { end.timeIntervalSince(start) }
}

struct IMUNRaceProjection: Identifiable {
    let name: String
    let distanceMeters: Double
    let predictedSeconds: Double
    let lowerSeconds: Double
    let upperSeconds: Double
    let basedOn: String
    var id: String { name }
}

struct IMUNRunRouteAssessment {
    let distanceMeters: Double
    let coveredFraction: Double?
    let elevationGainMeters: Double?
    let elevationLossMeters: Double?
    let uphillDistanceMeters: Double
    let downhillDistanceMeters: Double
    let reliableSegments: Int
    let discardedSegments: Int
    let source: String
}

struct IMUNRunZones {
    let labels: [String]
    let seconds: [Double]
    let thresholdLabel: String
    let recordedSeconds: Double
}

/// Segments and algorithms use only local, timestamped route samples and
/// source-published power/speed; the output is not a lab gait analysis.
enum IMUNRunAdvancedAnalytics {
    private struct RouteLeg {
        let start: Date
        let end: Date
        let meters: Double
        let climbMeters: Double?
    }

    static func distanceBetween(_ a: HCRunRoutePoint,
                                _ b: HCRunRoutePoint) -> Double {
        let rad = Double.pi / 180
        let lat1 = a.latitude * rad
        let lat2 = b.latitude * rad
        let dLat = (b.latitude - a.latitude) * rad
        let dLon = (b.longitude - a.longitude) * rad
        let h = pow(sin(dLat / 2), 2) +
            cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2)
        return 2 * 6_371_000 * atan2(sqrt(max(0, h)), sqrt(max(0, 1 - h)))
    }

    private static func routeLegs(_ run: HCProgressRun) -> ([RouteLeg], Int) {
        let valid = run.routePoints.filter { item in
            item.recordedAt != nil &&
            (-90...90).contains(item.latitude) &&
            (-180...180).contains(item.longitude)
        }.sorted {
            ($0.recordedAt ?? .distantPast) < ($1.recordedAt ?? .distantPast)
        }
        guard valid.count >= 8 else { return ([], 0) }
        var result: [RouteLeg] = []
        var dropped = 0
        for index in 1..<valid.count {
            let left = valid[index - 1]
            let right = valid[index]
            guard let start = left.recordedAt, let end = right.recordedAt else {
                continue
            }
            let seconds = end.timeIntervalSince(start)
            let meters = distanceBetween(left, right)
            // Downsampled route samples often have 5-40 second gaps. Longer
            // gaps, stationary jitter and vehicle-like speeds are not filled.
            guard seconds > 0, seconds <= 65, meters >= 1,
                  (meters / seconds) <= 10 else {
                dropped += 1
                continue
            }
            var rise: Double?
            if let earlier = left.altitudeMeters,
               let later = right.altitudeMeters,
               earlier.isFinite && later.isFinite {
                let delta = later - earlier
                // Ignore small altimeter noise and physically implausible
                // grade spikes; do not classify unknown altitude as flat.
                if abs(delta) < 2 { rise = 0 }
                else if abs(delta / meters) <= 0.35 { rise = delta }
            }
            result.append(RouteLeg(start: start, end: end,
                                   meters: meters, climbMeters: rise))
        }
        return (result, dropped)
    }

    static func routeAssessment(_ run: HCProgressRun) -> IMUNRunRouteAssessment? {
        let (legs, rejected) = routeLegs(run)
        guard legs.count >= 10 else { return nil }
        let meters = legs.reduce(0.0) { $0 + $1.meters }
        let fraction = run.distanceMeters.flatMap { distance in
            distance > 0 ? meters / distance : nil
        }
        let positives = legs.compactMap(\.climbMeters).filter { $0 > 0 }
        let negatives = legs.compactMap(\.climbMeters).filter { $0 < 0 }
        let hasAltitude = legs.filter { $0.climbMeters != nil }.count >= 8
        return IMUNRunRouteAssessment(
            distanceMeters: meters,
            coveredFraction: fraction,
            elevationGainMeters: hasAltitude ? positives.reduce(0,+) : nil,
            elevationLossMeters: hasAltitude ? -negatives.reduce(0,+) : nil,
            uphillDistanceMeters: legs.filter {
                ($0.climbMeters ?? 0) >= 2
            }.reduce(0) { $0 + $1.meters },
            downhillDistanceMeters: legs.filter {
                ($0.climbMeters ?? 0) <= -2
            }.reduce(0) { $0 + $1.meters },
            reliableSegments: legs.count, discardedSegments: rejected,
            source: run.source)
    }

    /// Uses contiguous route legs, linear distance/time interpolation, and
    /// requires good coverage relative to recorded workout distance.
    /// This is a GPS-derived rolling estimate; it is not a race PR.
    static func bestRouteSegments(_ run: HCProgressRun) -> [IMUNRunBestSegment] {
        let (legs, _) = routeLegs(run)
        guard legs.count >= 10, let reported = run.distanceMeters,
              reported > 0 else { return [] }
        let covered = legs.reduce(0.0) { $0 + $1.meters }
        guard covered / reported >= 0.80, covered / reported <= 1.20
        else { return [] }
        let targets: [Double] = [400, 1000, 1609.344, 5000, 10000]
        // Split the track into independent contiguous chains, so a GPS gap
        // cannot falsely create a faster route segment across missing time.
        var chains: [[RouteLeg]] = []
        var active: [RouteLeg] = []
        for leg in legs {
            if let prior = active.last,
               abs(leg.start.timeIntervalSince(prior.end)) > 1.0 {
                if active.count >= 3 { chains.append(active) }
                active = []
            }
            active.append(leg)
        }
        if active.count >= 3 { chains.append(active) }
        var results: [IMUNRunBestSegment] = []
        for target in targets where reported >= target * 0.98 {
            var best: IMUNRunBestSegment?
            for chain in chains {
                var offsets: [Double] = [0]
                for leg in chain {
                    offsets.append((offsets.last ?? 0) + leg.meters)
                }
                guard (offsets.last ?? 0) >= target else { continue }
                for startIndex in 0..<chain.count {
                    let goal = offsets[startIndex] + target
                    guard let last = offsets.last, goal <= last else { break }
                    var endIndex = startIndex + 1
                    while endIndex < offsets.count && offsets[endIndex] < goal {
                        endIndex += 1
                    }
                    guard endIndex <= chain.count else { continue }
                    let leg = chain[endIndex - 1]
                    let before = offsets[endIndex - 1]
                    let fraction = (goal - before) / max(leg.meters, 1)
                    let end = leg.start.addingTimeInterval(
                        leg.end.timeIntervalSince(leg.start) * fraction)
                    let beginning = chain[startIndex].start
                    let seconds = end.timeIntervalSince(beginning)
                    // Plausible running effort for a segment; no short
                    // sprints from two isolated, coarse GPS samples.
                    guard endIndex - startIndex >= 3,
                          seconds >= target / 10, seconds <= target / 0.8
                    else { continue }
                    let entry = IMUNRunBestSegment(
                        distanceMeters: target, elapsedSeconds: seconds,
                        start: beginning, end: end, source: run.source)
                    if best.map({ entry.elapsedSeconds < $0.elapsedSeconds }) ?? true {
                        best = entry
                    }
                }
            }
            if let best { results.append(best) }
        }
        return results
    }

    /// A burst in source-recorded speed is a candidate interval, never an
    /// assertion that the athlete completed prescribed repetitions.
    static func candidateSurges(_ run: HCProgressRun) -> [IMUNRunSurge] {
        let values = IMUNRunningIntelligence.metric(run, kind: "runningSpeed")
            .filter { (0.7...11).contains($0.value) }
        guard values.count >= 25 else { return [] }
        let ordered = values.map(\.value).sorted()
        let reference = ordered[ordered.count / 2]
        guard reference >= 1 else { return [] }
        let cutoff = reference * 1.16
        var groups: [[HCRunSensorReading]] = []
        var group: [HCRunSensorReading] = []
        for value in values {
            if value.value >= cutoff {
                if let last = group.last,
                   value.at.timeIntervalSince(last.at) > 45 {
                    if !group.isEmpty { groups.append(group) }
                    group = []
                }
                group.append(value)
            } else if !group.isEmpty {
                groups.append(group)
                group = []
            }
        }
        if !group.isEmpty { groups.append(group) }
        return groups.compactMap { sequence in
            guard let first = sequence.first, let last = sequence.last,
                  sequence.count >= 3 else { return nil }
            let duration = last.at.timeIntervalSince(first.at)
            guard duration >= 40, duration <= 1800 else { return nil }
            let speed = sequence.reduce(0.0) { $0 + $1.value } /
                Double(sequence.count)
            return IMUNRunSurge(start: first.at, end: last.at,
                                meanSpeedMPS: speed,
                                baselineSpeedMPS: reference)
        }.prefix(30).map { $0 }
    }

    /// Individualized, descriptive comparisons normalized by the closest
    /// recorded running speed. No "ideal" contact time or stride is assumed.
    static func mechanicsComparison(_ run: HCProgressRun,
                                    history: [HCProgressRun]) -> [IMUNRunningObservation] {
        guard let speed = run.averageRunningSpeedMPS,
              speed > 1.2 else { return [] }
        let peers = IMUNRunningIntelligence.uniqueRuns(history)
            .filter { other in
                other.id != run.id && other.date < run.date &&
                other.averageRunningSpeedMPS.map {
                    abs($0 - speed) / speed <= 0.08
                } == true
            }.prefix(20)
        guard peers.count >= 2 else { return [] }
        let metrics: [(String, String, KeyPath<HCProgressRun, Double?>, String)] = [
            ("Cadence", "Step frequency", \.averageCadenceSPM, "spm"),
            ("Stride", "Stride length", \.averageStrideLengthMeters, "m"),
            ("Contact", "Ground contact time", \.averageGroundContactTimeMS, "ms"),
            ("Oscillation", "Vertical oscillation", \.averageVerticalOscillationCM, "cm")
        ]
        return metrics.compactMap { key, title, path, unit in
            guard let current = run[keyPath: path],
                  current.isFinite else { return nil }
            let peersRecorded = peers.compactMap { $0[keyPath: path] }
            guard peersRecorded.count >= 2 else { return nil }
            let mean = peersRecorded.reduce(0,+) / Double(peersRecorded.count)
            return IMUNRunningObservation(id: "mechanics-\(key)",
                title: title + " at comparable speed",
                detail: String(format:
                    "Current %.1f %@; previous comparable runs averaged %.1f %@ (%d sessions). Differences can reflect surface, grade, shoes, device and intentional technique—not necessarily better or worse form.",
                    current, unit, mean, unit, peersRecorded.count))
        }
    }

    /// HRR is only calculated from *same-device* measurements after workout
    /// end and a last-minute in-run HR sample. Missing observations stay nil.
    static func heartRateRecovery(_ run: HCProgressRun) -> [IMUNRunningObservation] {
        guard let end = run.endedAt,
              let atEnd = run.heartRateTrace.filter({
                  abs($0.at.timeIntervalSince(end)) <= 45
              }).sorted(by: {
                  abs($0.at.timeIntervalSince(end)) <
                  abs($1.at.timeIntervalSince(end))
              }).first else { return [] }
        let baseline = atEnd.bpm
        return [60.0, 120.0].compactMap { seconds in
            let target = end.addingTimeInterval(seconds)
            let samples = (run.postRunHeartRateTrace ?? []).filter {
                abs($0.at.timeIntervalSince(target)) <= 20
            }
            guard let recorded = samples.min(by: {
                abs($0.at.timeIntervalSince(target)) <
                abs($1.at.timeIntervalSince(target))
            }) else { return nil }
            return IMUNRunningObservation(id: "hrr-\(Int(seconds))",
                title: "Heart-rate change after \(Int(seconds/60)) min",
                detail: String(format:
                    "%.0f bpm at run finish versus %.0f bpm measured after; change %+.0f bpm. Cool-down activity and sensor error affect interpretation.",
                    baseline, recorded.bpm, recorded.bpm - baseline))
        }
    }

    /// A threshold must be explicitly entered, not reverse-engineered from a
    /// short workout. Intervals count only observed adjacent sample periods.
    static func powerZones(_ run: HCProgressRun, criticalPower: Int) -> IMUNRunZones? {
        guard (100...900).contains(criticalPower) else { return nil }
        let points = IMUNRunningIntelligence.metric(run, kind: "runningPower")
        guard points.count >= 4 else { return nil }
        let edges = [0.0,0.80,0.90,1.00,1.15]
        var seconds = [Double](repeating: 0, count: 5)
        for i in 0..<(points.count - 1) {
            let dt = points[i+1].at.timeIntervalSince(points[i].at)
            guard dt > 0 && dt <= 90 else { continue }
            let ratio = points[i].value / Double(criticalPower)
            let z = ratio < edges[1] ? 0 :
                ratio < edges[2] ? 1 :
                ratio < edges[3] ? 2 :
                ratio < edges[4] ? 3 : 4
            seconds[z] += dt
        }
        return IMUNRunZones(labels: ["<80%", "80–90%", "90–100%", "100–115%", ">115%"],
                            seconds: seconds,
                            thresholdLabel: "\(criticalPower) W user-entered critical power",
                            recordedSeconds: seconds.reduce(0,+))
    }

    static func paceZones(_ run: HCProgressRun,
                          thresholdSecondsPerMile: Int) -> IMUNRunZones? {
        guard (230...1200).contains(thresholdSecondsPerMile) else { return nil }
        let points = IMUNRunningIntelligence.metric(run, kind: "runningSpeed")
        guard points.count >= 4 else { return nil }
        let reference = IMUNRunningIntelligence.mile /
            Double(thresholdSecondsPerMile)
        var seconds = [Double](repeating: 0, count: 5)
        for i in 0..<(points.count - 1) {
            let dt = points[i + 1].at.timeIntervalSince(points[i].at)
            guard dt > 0 && dt <= 90 else { continue }
            let speedRatio = points[i].value / reference
            let index = speedRatio < 0.80 ? 0 :
                speedRatio < 0.90 ? 1 :
                speedRatio < 1.00 ? 2 :
                speedRatio < 1.10 ? 3 : 4
            seconds[index] += dt
        }
        return IMUNRunZones(labels: ["<80%", "80–90%", "90–100%", "100–110%", ">110%"],
            seconds: seconds,
            thresholdLabel: IMUNRunningIntelligence.formatPace(
                Double(thresholdSecondsPerMile)) + "/mi user-entered threshold pace",
            recordedSeconds: seconds.reduce(0,+))
    }

    /// Extrapolate from a *recorded whole-distance effort*, not a best GPS
    /// subsegment. Riegel exponent is a rough empirical heuristic; confidence
    /// deteriorates with distance, terrain, training and racing intent.
    static func raceForecasts(_ runs: [HCProgressRun]) -> [IMUNRaceProjection] {
        let efforts = IMUNRunningIntelligence.bestEfforts(runs)
        let plans: [(String, Double)] = [
            ("5K",5000), ("10K",10000),
            ("Half marathon",21097.5), ("Marathon",42195)
        ]
        let baseChoices = efforts.filter {
            $0.targetMeters >= 5000 && $0.targetMeters <= 21097.5 &&
            $0.timeSeconds > 500
        }
        return plans.compactMap { name, meters in
            let eligible = baseChoices.filter {
                let ratio = meters / $0.targetMeters
                return ratio >= 0.5 && ratio <= 3.0
            }
            guard let source = eligible.min(by: {
                abs(log(meters / $0.targetMeters)) <
                    abs(log(meters / $1.targetMeters))
            }) else { return nil }
            let distanceRatio = meters / source.targetMeters
            // Limit displayed models to plausible recreational duration.
            let predicted = source.timeSeconds * pow(distanceRatio, 1.06)
            guard predicted >= 600 && predicted <= 10 * 3600 else { return nil }
            let uncertainty = 0.07 + min(0.13, abs(log(distanceRatio)) * 0.07)
            return IMUNRaceProjection(name: name,
                distanceMeters: meters, predictedSeconds: predicted,
                lowerSeconds: predicted * (1 - uncertainty),
                upperSeconds: predicted * (1 + uncertainty),
                basedOn: "\(source.distanceName), \(source.date) · \(source.source)")
        }
    }

    /// Descriptive pacing from actually recorded complete laps or route
    /// miles; only equally sized laps are compared. This is not a judgment
    /// about intentional progression or training success.
    static func pacingPattern(_ run: HCProgressRun) -> IMUNRunningObservation? {
        let splits = (run.routeMileSplits ?? []).filter {
            $0.distanceMeters.map {
                abs($0 - IMUNRunningIntelligence.mile) <= 15
            } == true && $0.elapsedSeconds > 90
        }
        guard splits.count >= 4 else { return nil }
        let count = splits.count / 2
        let early = splits.prefix(count).map(\.elapsedSeconds)
        let late = splits.suffix(count).map(\.elapsedSeconds)
        let first = early.reduce(0,+) / Double(count)
        let last = late.reduce(0,+) / Double(count)
        let percent = 100 * abs(last - first) / max(first, 1)
        let label = percent < 1.5 ? "similar" :
            last < first ? "faster" : "slower"
        return IMUNRunningObservation(id: "measured-pacing",
            title: "First versus last complete-mile splits",
            detail: String(format:
                "The final %d complete route miles averaged %.1f%% %@ per mile than the first %d. Derived GPS splits exclude any unfinished final mile; conditions and route grade can explain differences.",
                count, percent, label, count))
    }

    static func aerobicEfficiency(_ run: HCProgressRun,
                                  history: [HCProgressRun]) -> IMUNRunningObservation? {
        guard let speed = run.averageRunningSpeedMPS,
              let heart = run.averageBPM,
              speed.isFinite, heart.isFinite,
              (1.2...8.5).contains(speed),
              (70...220).contains(heart) else { return nil }
        let peers = IMUNRunningIntelligence.uniqueRuns(history).filter {
            $0.id != run.id && $0.date < run.date &&
            $0.averageRunningSpeedMPS.map {
                abs($0-speed)/speed < 0.12
            } == true &&
            $0.averageBPM.map { (70...220).contains($0) } == true
        }
        guard peers.count >= 3 else { return nil }
        let earlier = Array(peers.prefix(12))
        let ratios: [Double] = earlier.compactMap {
            guard let pace = $0.averageRunningSpeedMPS,
                  let bpm = $0.averageBPM,
                  bpm > 0 else { return nil }
            return pace / bpm
        }
        guard ratios.count >= 3 else { return nil }
        let reference = ratios.reduce(0,+) / Double(ratios.count)
        let this = speed / heart
        let percent = 100 * (this - reference) / max(reference, 0.001)
        return IMUNRunningObservation(id: "speed-to-hr",
            title: "Speed-to-heart-rate observation",
            detail: String(format:
                "Current recorded speed/HR ratio %.4f versus %.4f from %d comparable-speed runs (%+.1f%%). This is a descriptive proxy—not a measured running economy or oxygen-consumption test.",
                this, reference, ratios.count, percent))
    }

    /// A four-week *preview* based on recorded mileage and any optional goal.
    /// Never changes HealthKit, Tredict, calendar, or coach prescriptions.
    static func fourWeekPreview(_ runs: [HCProgressRun],
                                targetMiles: Double?,
                                raceDate: Date?,
                                now: Date = Date())
        -> [(week: Int, miles: Double, focus: String)] {
        let load = IMUNRunningIntelligence.weeklyLoad(runs, now: now)
        guard load.distinctRuns7 >= 2,
              let prior = load.prior21WeeklyMiles,
              load.comparisons >= 3,
              prior > 1.5 else { return [] }
        let base = max(1, min(load.recent7Miles, prior * 1.15))
        let cappedGoal = targetMiles.flatMap {
            $0.isFinite && $0 > 0 ? $0 : nil
        }
        let daysToRace: Int? = raceDate.flatMap {
            Calendar.current.dateComponents([.day], from: now, to: $0).day
        }
        let taper = daysToRace.map { $0 >= 7 && $0 <= 28 } ?? false
        let factors: [Double] = taper ? [1, 0.85, 0.70, 0.50] :
            [1, 1.05, 1.10, 0.85]
        return (0..<4).map { index in
            let unconstrained = base * factors[index]
            let capped = cappedGoal.map {
                min(unconstrained, max(base, $0))
            } ?? unconstrained
            let focus: String
            if taper {
                focus = index == 3 ? "Taper/race week; race miles excluded" :
                    "Keep routine, reduce nonessential volume"
            } else if index == 3 {
                focus = "Lower-volume consolidation"
            } else if base < 15 || load.distinctRuns7 < 3 {
                focus = "Consistent easy runs and rest days"
            } else {
                focus = "Mostly easy mileage; one purposeful session if recovered"
            }
            return (week: index + 1, miles: capped, focus: focus)
        }
    }

    static func trainingLoadNote(_ runs: [HCProgressRun]) -> String? {
        let load = IMUNRunningIntelligence.weeklyLoad(runs)
        guard let baseline = load.prior21WeeklyMiles,
              baseline >= 3, load.comparisons >= 3 else { return nil }
        let difference = load.recent7Miles - baseline
        return String(format:
            "Past seven days %.1f mi versus %.1f mi/week in the preceding 21 days (%+.0f%%). Review the planned workload, recovery and whether recent runs were easy or demanding. Volume change by itself is not an injury-risk score.",
            load.recent7Miles, baseline, 100 * difference / baseline)
    }

    static func insightSummary(_ run: HCProgressRun,
                               history: [HCProgressRun],
                               power: Int,
                               pace: Int) -> String {
        var sentences: [String] = []
        let efforts = bestRouteSegments(run)
        if !efforts.isEmpty {
            sentences.append("GPS rolling efforts: " + efforts.map {
                "\($0.distanceLabel) \(IMUNRunningIntelligence.formatPace($0.elapsedSeconds * IMUNRunningIntelligence.mile / $0.distanceMeters))/mi"
            }.joined(separator: ", ") + ".")
        }
        if let terrain = routeAssessment(run) {
            sentences.append(String(format:
                "GPS route valid %.0f m (%d reliable, %d rejected segments); sampled coverage %@; ascent %@.",
                terrain.distanceMeters, terrain.reliableSegments,
                terrain.discardedSegments,
                terrain.coveredFraction.map {
                    String(format:"%.0f%%", $0 * 100)
                } ?? "unknown",
                terrain.elevationGainMeters.map {
                    String(format:"%.0f m", $0)
                } ?? "not available"))
        }
        if let pacing = pacingPattern(run) {
            sentences.append(pacing.detail)
        }
        if let efficient = aerobicEfficiency(run, history: history) {
            sentences.append(efficient.detail)
        }
        if let loadNote = trainingLoadNote(history) {
            sentences.append(loadNote)
        }
        let surges = candidateSurges(run)
        if !surges.isEmpty {
            sentences.append("\(surges.count) candidate higher-speed surges, not verified prescribed intervals.")
        }
        sentences.append(contentsOf:
            mechanicsComparison(run, history: history).map(\.detail))
        sentences.append(contentsOf: heartRateRecovery(run).map(\.detail))
        if let zones = powerZones(run, criticalPower: power) {
            sentences.append("Power zones based on " + zones.thresholdLabel + ": " +
                zip(zones.labels,zones.seconds).map {
                    "\($0.0) \(Int($0.1)) s"
                }.joined(separator:", "))
        }
        if let zones = paceZones(run, thresholdSecondsPerMile: pace) {
            sentences.append("Pace zones based on " + zones.thresholdLabel + ": " +
                zip(zones.labels,zones.seconds).map {
                    "\($0.0) \(Int($0.1)) s"
                }.joined(separator:", "))
        }
        return sentences.joined(separator:"\n")
    }
}
