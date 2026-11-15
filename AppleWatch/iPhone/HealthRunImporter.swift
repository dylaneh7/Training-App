import Foundation
import HealthKit
import Combine

/// Imports completed running workouts from the authorized Apple Health store.
/// This includes third-party workouts (e.g. WHOOP) only if they have actually
/// been written to Apple Health with the necessary read permissions.
///
/// Background observer delivery requires the HealthKit Background Delivery
/// capability and is not testable in the iOS Simulator.
final class HCRunHealthImporter: ObservableObject {
    @Published private(set) var runs: [HCProgressRun] = []
    @Published private(set) var status = "Connect Apple Health to import completed runs."
    @Published private(set) var enabled = UserDefaults.standard.bool(forKey: "hcAutomaticRunImport")
    @Published private(set) var refreshing = false

    private let store = HKHealthStore()
    private var observer: HKObserverQuery?
    private var isLoading = false
    private var pendingCompletions: [HKObserverQueryCompletionHandler] = []
    private let formatter = DateFormatter()
    private let cache = "health-coach-imported-runs.json"

    init() {
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        if let url = try? cacheURL(),
           let bytes = try? Data(contentsOf: url),
           let stored = try? JSONDecoder().decode([HCProgressRun].self, from: bytes) {
            runs = stored
        }
        if enabled { startIfAuthorized() }
    }

    private func cacheURL() throws -> URL {
        guard let folder = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask).first
        else { throw NSError(domain: "Health Coach", code: 1) }
        return folder.appendingPathComponent(cache)
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
            .runningPower, .runningSpeed, .stepCount
        ]
        var readable: Set<HKObjectType> = [HKObjectType.workoutType()]
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
        let earliest = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
        let predicate = HKQuery.predicateForSamples(withStart: earliest, end: nil)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                  predicate: predicate, limit: 750,
                                  sortDescriptors: [sort]) { [weak self] _, results, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.status = "Apple Health run import: \(error.localizedDescription)"
                } else {
                    let workouts = (results as? [HKWorkout] ?? [])
                        .filter { $0.workoutActivityType == .running }
                    let incoming = workouts.map { self.convert($0) }
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
                    self.status = self.runs.isEmpty
                        ? "No running workouts were shared with Health Coach."
                        : "Imported \(self.runs.count) runs from Apple Health."
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
