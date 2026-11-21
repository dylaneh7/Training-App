import Foundation
import HealthKit
import CoreLocation
import Combine

/// Imports completed running workouts from the authorized Apple Health store.
/// This includes third-party workouts (e.g. WHOOP) only if they have actually
/// been written to Apple Health with the necessary read permissions.
///
/// Background observer delivery requires the HealthKit Background Delivery
/// capability and is not testable in the iOS Simulator.
final class HCRunHealthImporter: ObservableObject {
    @Published private(set) var runs: [HCProgressRun] = []
    // All authorized Apple Health exercise sessions, not just running.
    // Remains on-device; IsAIah only receives selected summaries on consent.
    @Published private(set) var workouts: [HCTrainingActivity] = []
    @Published private(set) var status = "Connect Apple Health to import completed runs."
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "hcAutomaticRunImport")
    @Published private(set) var refreshing = false

    private let store = HKHealthStore()
    private var observer: HKObserverQuery?
    private var isLoading = false
    private var pendingCompletions: [HKObserverQueryCompletionHandler] = []
    private let formatter = DateFormatter()
    private let cache = "health-coach-imported-runs.json"
    private let workoutCache = "imun-apple-health-exercise-history.json"

    init() {
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        enabled = UserDefaults.standard.bool(forKey: "hcAutomaticRunImport") ||
            UserDefaults.standard.bool(forKey: "hcHealthCatalogEnabled")
        if let url = try? cacheURL(named: workoutCache),
           let bytes = try? Data(contentsOf: url),
           let stored = try? JSONDecoder().decode([HCTrainingActivity].self, from: bytes) {
            workouts = stored
        }
        if let url = try? cacheURL(),
           let bytes = try? Data(contentsOf: url),
           let stored = try? JSONDecoder().decode([HCProgressRun].self, from: bytes) {
            runs = stored
        }
        if enabled { startIfAuthorized() }
    }

    private func cacheURL(named fileName: String = "health-coach-imported-runs.json") throws -> URL {
        guard let folder = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask).first
        else { throw NSError(domain: "Health Coach", code: 1) }
        return folder.appendingPathComponent(fileName)
    }

    /// The user explicitly opts in; HealthKit permission is never requested on
    /// a background app launch without an earlier user action.
    func connect() {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Health isn't available in this simulator. Use a real iPhone."
            return
        }
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning, .heartRate, .activeEnergyBurned,
            .runningPower, .runningSpeed, .stepCount,
            .runningStrideLength, .runningVerticalOscillation,
            .runningGroundContactTime
        ]
        var readable: Set<HKObjectType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        for id in quantityIDs {
            if let kind = HKObjectType.quantityType(forIdentifier: id) { readable.insert(kind) }
        }
        store.requestAuthorization(toShare: [], read: readable) { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.status = "Apple Health permission failed: \(error.localizedDescription)"
                } else if success {
                    self.enabled = true
                    UserDefaults.standard.set(true, forKey: "hcAutomaticRunImport")
                    self.status = "Import enabled. Only runs shared through Apple Health are available."
                    self.startIfAuthorized()
                } else {
                    self.status = "Apple Health access wasn't completed. No workouts imported."
                }
            }
        }
    }

    func startIfAuthorized() {
        // Health catalog permission includes workout-read authorization.
        // Start the local importer when that existing user grant is enabled.
        if !enabled && UserDefaults.standard.bool(forKey: "hcHealthCatalogEnabled") {
            enabled = true
        }
        guard enabled else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            status = "Apple Health requires a physical iPhone."
            return
        }
        if observer == nil {
            let query = HKObserverQuery(sampleType: HKObjectType.workoutType(),
                                        predicate: nil) { [weak self] _, completion, error in
                guard let self else { completion(); return }
                if let error {
                    DispatchQueue.main.async {
                        self.status = "Health workout observer: \(error.localizedDescription)"
                    }
                    completion()
                    return
                }
                self.reload(after: completion)
            }
            observer = query
            store.execute(query)

            // If the provisioning profile supports HealthKit Background
            // Delivery, the system can also wake us when another app saves a
            // workout. Foreground rechecks remain the reliable fallback.
            store.enableBackgroundDelivery(for: HKObjectType.workoutType(),
                                           frequency: .immediate) { [weak self] ok, error in
                if !ok {
                    DispatchQueue.main.async {
                        self?.status = "Foreground auto-import enabled; background notifications: \(error?.localizedDescription ?? "unavailable")."
                    }
                }
            }
        }
        refresh()
    }

    func refresh() { reload(after: nil) }

    private func reload(after completion: HKObserverQueryCompletionHandler?) {
        DispatchQueue.main.async {
            if let completion { self.pendingCompletions.append(completion) }
            guard !self.isLoading else { return }
            self.isLoading = true
            self.refreshing = true
            self.queryRecent()
        }
    }

    private func queryRecent() {
        // No two-year cutoff: historical runs and all other exercise types
        // should remain searchable. This loads summaries, not raw route traces.
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                  predicate: nil, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sort]) { [weak self] _, results, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.status = "Apple Health run import: \(error.localizedDescription)"
                } else {
                    let allWorkouts = results as? [HKWorkout] ?? []
                    self.workouts = allWorkouts.map { self.convertActivity($0) }
                    if let url = try? self.cacheURL(named: self.workoutCache),
                       let bytes = try? JSONEncoder().encode(self.workouts) {
                        try? bytes.write(to: url, options: .atomic)
                    }
                    let workouts = allWorkouts.filter {
                        $0.workoutActivityType == .running
                    }
                    let previous = Dictionary(self.runs.map { ($0.id, $0) },
                                              uniquingKeysWith: { current, _ in current })
                    let incoming = workouts.map { workout -> HCProgressRun in
                        var item = self.convert(workout)
                        if let stored = previous[item.id] {
                            item.heartRateTrace = stored.heartRateTrace
                            item.routePoints = stored.routePoints
                            item.sensorSeries = stored.sensorSeries
                            item.postRunHeartRateTrace = stored.postRunHeartRateTrace
                            item.averageStrideLengthMeters = stored.averageStrideLengthMeters
                            item.averageGroundContactTimeMS = stored.averageGroundContactTimeMS
                            item.averageVerticalOscillationCM = stored.averageVerticalOscillationCM
                            item.averageRunningSpeedMPS = stored.averageRunningSpeedMPS
                            if item.averageBPM == nil { item.averageBPM = stored.averageBPM }
                            if item.maxBPM == nil { item.maxBPM = stored.maxBPM }
                        }
                        return item
                    }
                    // Stable HealthKit workout UUIDs make repeated imports
                    // idempotent. WHOOP and Apple may both save one event;
                    // that cross-source duplicate is resolved in the bridge.
                    self.runs = incoming.sorted {
                        ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast)
                    }
                    if let url = try? self.cacheURL(),
                       let bytes = try? JSONEncoder().encode(self.runs) {
                        try? bytes.write(to: url, options: .atomic)
                    }
                    self.status = allWorkouts.isEmpty
                        ? "No workouts are available from the authorized Apple Health source."
                        : "Loaded \(allWorkouts.count) Apple Health workouts, including \(self.runs.count) runs."
                    // Detailed HR samples and GPS routes can arrive after the
                    // original workout. Query recent items without blocking
                    // the observer completion handler or summary display.
                    for workout in workouts.prefix(16) {
                        self.enrichHeartRate(workout)
                        self.enrichRoute(workout)
                    }
                    for workout in workouts.prefix(8) {
                        self.enrichRunningDynamics(workout)
                        self.enrichPostRunHeartRate(workout)
                    }
                }
                self.isLoading = false
                self.refreshing = false
                let completions = self.pendingCompletions
                self.pendingCompletions.removeAll()
                completions.forEach { $0() }
            }
        }
        store.execute(query)
    }

    private func patchRun(id: String, apply: (inout HCProgressRun) -> Void) {
        guard let index = runs.firstIndex(where: { $0.id == id }) else { return }
        var item = runs[index]
        apply(&item)
        runs[index] = item
        if let url = try? cacheURL(), let data = try? JSONEncoder().encode(runs) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Use samples from the SAME HealthKit source as the workout to avoid
    /// silently combining simultaneous WHOOP and Apple Watch sensors.
    private func enrichHeartRate(_ workout: HKWorkout) {
        let id = "healthkit:\(workout.uuid.uuidString)"
        guard let current = runs.first(where: { $0.id == id }),
              current.heartRateTrace.isEmpty,
              let kind = HKObjectType.quantityType(forIdentifier: .heartRate)
        else { return }

        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate,
                                                     end: workout.endDate,
                                                     options: [.strictStartDate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: kind, predicate: predicate,
                                  limit: 15000, sortDescriptors: [sort]) { [weak self] _, found, error in
            guard error == nil else { return }
            let source = workout.sourceRevision.source.bundleIdentifier
            let unit = HKUnit.count().unitDivided(by: .minute())
            let values = (found as? [HKQuantitySample] ?? []).filter {
                $0.sourceRevision.source.bundleIdentifier == source
            }.map {
                HCRunHeartPoint(at: $0.startDate, bpm: $0.quantity.doubleValue(for: unit))
            }
            guard !values.isEmpty else { return }
            // Keep an evenly sampled, chart-friendly trace; calculate summary
            // using all of the retrieved same-source measurements.
            let stride = max(1, Int(ceil(Double(values.count) / 450.0)))
            let chart = values.enumerated().compactMap { index, value in
                index % stride == 0 ? value : nil
            }
            let avg = values.map(\.bpm).reduce(0, +) / Double(values.count)
            let high = values.map(\.bpm).max()
            DispatchQueue.main.async {
                self?.patchRun(id: id) { run in
                    run.heartRateTrace = chart
                    if run.averageBPM == nil { run.averageBPM = avg }
                    if run.maxBPM == nil { run.maxBPM = high }
                }
            }
        }
        store.execute(query)
    }

    /// Keep source-specific, time-stamped running dynamics local. Garmin/
    /// Tredict sessions are not assumed to have unshared Apple Watch signals.
    private func enrichRunningDynamics(_ workout: HKWorkout) {
        let id = "healthkit:\(workout.uuid.uuidString)"
        guard let existing = runs.first(where: { $0.id == id }) else { return }
        let metrics: [(type: HKQuantityTypeIdentifier, key: String, unit: HKUnit)] = [
            (.runningPower, "runningPower", .watt()),
            (.runningSpeed, "runningSpeed", .meter().unitDivided(by: .second())),
            (.runningStrideLength, "runningStrideLength", .meter()),
            (.runningVerticalOscillation, "runningVerticalOscillation",
             .meterUnit(with: .centi)),
            (.runningGroundContactTime, "runningGroundContactTime",
             .secondUnit(with: .milli))
        ]
        let source = workout.sourceRevision.source.bundleIdentifier
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate, end: workout.endDate,
            options: [.strictStartDate])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate,
                                    ascending: true)
        for metric in metrics {
            if existing.sensorSeries?.contains(where: { $0.kind == metric.key }) == true {
                continue
            }
            guard let quantityType = HKObjectType.quantityType(
                forIdentifier: metric.type) else { continue }
            let query = HKSampleQuery(sampleType: quantityType,
                                      predicate: predicate, limit: 4000,
                                      sortDescriptors: [sort]) { [weak self] _, found, error in
                guard error == nil,
                      let found = found as? [HKQuantitySample] else { return }
                let series: [HCRunSensorReading] = found.compactMap { sample in
                    guard sample.sourceRevision.source.bundleIdentifier == source else {
                        return nil
                    }
                    let value = sample.quantity.doubleValue(for: metric.unit)
                    guard value.isFinite, value > 0 else { return nil }
                    return HCRunSensorReading(kind: metric.key,
                                              at: sample.startDate, value: value)
                }
                guard !series.isEmpty else { return }
                let sorted = series.map(\.value).sorted()
                let midpoint = sorted.count / 2
                let median = sorted.count.isMultiple(of: 2)
                    ? (sorted[midpoint - 1] + sorted[midpoint]) / 2
                    : sorted[midpoint]
                let stride = max(1, Int(ceil(Double(series.count) / 480)))
                let condensed = series.enumerated().compactMap { index, sample in
                    index % stride == 0 ? sample : nil
                }
                DispatchQueue.main.async {
                    self?.patchRun(id: id) { run in
                        var values = (run.sensorSeries ?? []).filter {
                            $0.kind != metric.key
                        }
                        values.append(contentsOf: condensed)
                        run.sensorSeries = values.sorted { $0.at < $1.at }
                        switch metric.key {
                        case "runningPower":
                            if run.averagePowerWatts == nil {
                                run.averagePowerWatts = median
                            }
                        case "runningSpeed": run.averageRunningSpeedMPS = median
                        case "runningStrideLength": run.averageStrideLengthMeters = median
                        case "runningVerticalOscillation": run.averageVerticalOscillationCM = median
                        case "runningGroundContactTime": run.averageGroundContactTimeMS = median
                        default: break
                        }
                    }
                }
            }
            store.execute(query)
        }
    }

    private func enrichRoute(_ workout: HKWorkout) {
        let id = "healthkit:\(workout.uuid.uuidString)"
        guard runs.first(where: { $0.id == id })?.routePoints.isEmpty == true else { return }

        let predicate = HKQuery.predicateForObjects(from: workout)
        let sampleQuery = HKSampleQuery(sampleType: HKSeriesType.workoutRoute(),
                                        predicate: predicate, limit: 4,
                                        sortDescriptors: nil) { [weak self] _, found, error in
            guard error == nil, let route = (found as? [HKWorkoutRoute])?.first else { return }
            var coordinates: [CLLocation] = []
            let routeQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, failure in
                DispatchQueue.main.async {
                    guard failure == nil else { return }
                    coordinates.append(contentsOf: locations ?? [])
                    guard done, !coordinates.isEmpty else { return }
                    let stride = max(1, Int(ceil(Double(coordinates.count) / 650.0)))
                    let path = coordinates.enumerated().compactMap { index, value -> HCRunRoutePoint? in
                        guard index % stride == 0 || index == coordinates.count - 1 else { return nil }
                        return HCRunRoutePoint(latitude: value.coordinate.latitude,
                                               longitude: value.coordinate.longitude,
                                               altitudeMeters: value.altitude,
                                               recordedAt: value.timestamp)
                    }
                    let derived = self?.gpsMileSplits(
                        coordinates, workoutDistance: workout.totalDistance?
                            .doubleValue(for: .meter()))
                    self?.patchRun(id: id) { run in
                        run.routePoints = path
                        run.routeMileSplits = derived
                    }
                }
            }
            self?.store.execute(routeQuery)
        }
        store.execute(sampleQuery)
    }

    /// Derive a distance/time split from valid GPS evidence, never from
    /// a total-workout average. Reject low-coverage or implausible GPS traces.
    private func gpsMileSplits(_ points: [CLLocation],
                               workoutDistance: Double?) -> [HCRunSplit]? {
        let sorted = points.filter {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 35
        }.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count >= 20, let first = sorted.first else { return nil }
        var distance = 0.0
        var previous = first
        var lastSplitAt = first.timestamp
        let mile = 1609.344
        var splits: [HCRunSplit] = []
        for location in sorted.dropFirst() {
            let dt = location.timestamp.timeIntervalSince(previous.timestamp)
            guard dt > 0, dt <= 45 else {
                previous = location
                continue
            }
            let segment = location.distance(from: previous)
            if segment > 0.5 && segment / dt <= 12.0 {
                let before = distance
                distance += segment
                let nextMile = Double(splits.count + 1) * mile
                if before < nextMile && distance >= nextMile {
                    let fraction = (nextMile - before) / segment
                    let reachedAt = previous.timestamp.addingTimeInterval(dt * fraction)
                    let elapsed = reachedAt.timeIntervalSince(lastSplitAt)
                    if elapsed >= 120 && elapsed <= 5400 {
                        splits.append(HCRunSplit(index: splits.count + 1,
                                                 elapsedSeconds: elapsed,
                                                 distanceMeters: mile))
                        lastSplitAt = reachedAt
                    }
                }
            }
            previous = location
        }
        guard !splits.isEmpty, distance >= mile,
              workoutDistance.map({ abs(distance - $0) / max($0, 1) < 0.20 }) ?? true
        else { return nil }
        return splits
    }

    /// One source-attributed activity for every exercise type HealthKit exposes.
    /// The app deliberately does not export raw GPS routes or granular HR traces
    /// to the online coach through this activity summary.
    private func convertActivity(_ workout: HKWorkout) -> HCTrainingActivity {
        let kind: String
        switch workout.workoutActivityType {
        case .running: kind = "run"
        case .walking: kind = "walk"
        case .cycling: kind = "cycle"
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            kind = "lift"
        case .swimming: kind = "swim"
        case .hiking: kind = "hike"
        case .rowing: kind = "row"
        default: kind = String(describing: workout.workoutActivityType)
        }
        let source = workout.sourceRevision.source
        let sourceName = source.name.isEmpty ? "Apple Health" : source.name
        let meters = workout.totalDistance?.doubleValue(for: .meter())
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)
        let heart = heartRateType.flatMap { workout.statistics(for: $0) }
        let avg = heart?.averageQuantity()?.doubleValue(for: bpm)
        let maxHR = heart?.maximumQuantity()?.doubleValue(for: bpm)
        var row = HCTrainingActivity(
            id: "healthkit:\(workout.uuid.uuidString)",
            date: formatter.string(from: workout.startDate),
            title: kind.capitalized + " Workout", kind: kind,
            source: sourceName, distanceMeters: meters,
            durationSeconds: workout.duration,
            averageBPM: avg, maxBPM: maxHR, calories: calories,
            perceivedEffort: nil)
        row.attribution = source.bundleIdentifier
        row.externalID = workout.uuid.uuidString
        row.totalDurationSeconds = workout.duration
        return row
    }

    private func convert(_ workout: HKWorkout) -> HCProgressRun {
        func quantity(_ identifier: HKQuantityTypeIdentifier,
                      unit: HKUnit, option: String = "sum") -> Double? {
            guard let type = HKObjectType.quantityType(forIdentifier: identifier),
                  let result = workout.statistics(for: type) else { return nil }
            let value: HKQuantity?
            if option == "avg" { value = result.averageQuantity() }
            else if option == "max" { value = result.maximumQuantity() }
            else { value = result.sumQuantity() }
            return value?.doubleValue(for: unit)
        }

        let distance = quantity(.distanceWalkingRunning, unit: .meter())
            ?? workout.totalDistance?.doubleValue(for: .meter())
        let calories = quantity(.activeEnergyBurned, unit: .kilocalorie())
            ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let pulseUnit = HKUnit.count().unitDivided(by: .minute())
        let averageHR = quantity(.heartRate, unit: pulseUnit, option: "avg")
        let maxHR = quantity(.heartRate, unit: pulseUnit, option: "max")
        let power = quantity(.runningPower, unit: .watt(), option: "avg")
        let steps = quantity(.stepCount, unit: .count())
        let cadence = steps.flatMap { workout.duration > 0 ? $0 / (workout.duration / 60) : nil }
        let elevation = (workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?
            .doubleValue(for: .meter())

        let source = workout.sourceRevision.source
        let sourceName = source.name.isEmpty ? "Apple Health" : source.name

        // Lap timing only comes from actual lap events supplied by the recorder.
        // It is not a fabricated one-mile split.
        var lapSplits: [HCRunSplit] = []
        var previous = workout.startDate
        for event in (workout.workoutEvents ?? [])
            .filter({ $0.type == .lap })
            .sorted(by: { $0.dateInterval.end < $1.dateInterval.end }) {
            let end = event.dateInterval.end
            let elapsed = end.timeIntervalSince(previous)
            if elapsed >= 1 {
                lapSplits.append(HCRunSplit(index: lapSplits.count + 1,
                                            elapsedSeconds: elapsed,
                                            distanceMeters: nil))
                previous = end
            }
        }

        var imported = HCProgressRun(
            id: "healthkit:\(workout.uuid.uuidString)",
            date: formatter.string(from: workout.startDate),
            title: "Recorded Run",
            source: sourceName,
            distanceMeters: distance,
            durationSeconds: workout.duration,
            averageBPM: averageHR,
            splits: lapSplits
        )
        imported.startedAt = workout.startDate
        imported.endedAt = workout.endDate
        imported.maxBPM = maxHR
        imported.activeCalories = calories
        imported.averagePowerWatts = power
        imported.averageCadenceSPM = cadence
        imported.elevationGainMeters = elevation
        imported.sourceBundleID = source.bundleIdentifier
        imported.fromAppleHealth = true
        return imported
    }
}
