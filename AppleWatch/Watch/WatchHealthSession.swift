import Foundation
import Combine
import HealthKit

/// Optional Apple Health recorder. Strength-set clocks and running elapsed time
/// continue working if the user chooses not to grant HealthKit access.
final class WatchHealthSession: NSObject, ObservableObject,
                                HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    enum Kind { case strength, run }

    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var kind: Kind?
    @Published private(set) var heartRateBPM: Double?
    @Published private(set) var averageHeartRateBPM: Double?
    @Published private(set) var distanceMeters: Double?
    @Published private(set) var message = "Apple Fitness ready"

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var ending = false

    func start(kind requestedKind: Kind) {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "Apple Health unavailable. Training timers still work."
            return
        }
        guard session == nil && !isRunning && !ending else {
            message = "Finish the current Apple Fitness session first."
            return
        }

        let heart = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        store.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                   read: [heart, distance]) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.message = "Apple Health access: \(error.localizedDescription)"
                } else {
                    self.begin(kind: requestedKind)
                }
            }
        }
    }

    private func begin(kind requestedKind: Kind) {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = requestedKind == .run ? .running : .traditionalStrengthTraining
        configuration.locationType = requestedKind == .run ? .outdoor : .indoor

        do {
            let next = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let collector = next.associatedWorkoutBuilder()
            collector.dataSource = HKLiveWorkoutDataSource(healthStore: store,
                                                            workoutConfiguration: configuration)
            next.delegate = self
            collector.delegate = self
            session = next
            builder = collector
            kind = requestedKind
            heartRateBPM = nil
            distanceMeters = nil
            averageHeartRateBPM = nil

            let now = Date()
            next.startActivity(with: now)
            collector.beginCollection(withStart: now) { [weak self] success, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.session === next else { return }
                    self.isRunning = success
                    self.message = success
                        ? (requestedKind == .run ? "Apple Fitness run recording" : "Apple Fitness strength recording")
                        : (error?.localizedDescription ?? "Could not record Apple Fitness workout")
                    if !success {
                        self.session?.end()
                        self.builder = nil
                        self.session = nil
                        self.kind = nil
                    }
                }
            }
        } catch {
            message = "Fitness start unavailable: \(error.localizedDescription)"
        }
    }

    func pause() {
        guard isRunning && !isPaused else { return }
        session?.pause()
        isPaused = true
    }

    func resume() {
        guard isRunning && isPaused else { return }
        session?.resume()
        isPaused = false
    }

    /// Undo an in-progress workout without saving a HealthKit workout.
    /// This is intentionally separate from Finish & Save.
    func undo() {
        guard let current = session else {
            message = "Workout undone"
            reset()
            return
        }
        ending = false
        builder?.discardWorkout()
        current.end()
        reset()
        heartRateBPM = nil
        averageHeartRateBPM = nil
        distanceMeters = nil
        message = "Workout undone · nothing saved to Apple Fitness"
    }

    /// Use stopActivity and wait for the stopped delegate state before finishing
    /// HKLiveWorkoutBuilder. This follows Apple's current HealthKit lifecycle.
    func finish() {
        guard session != nil && !ending else { return }
        ending = true
        session?.stopActivity(with: Date())
        message = "Saving Apple Fitness workout…"
    }

    private func finishRecording(end: Date) {
        guard let current = session, let collector = builder else {
            reset(); return
        }
        collector.endCollection(withEnd: end) { [weak self] success, error in
            guard let self else { return }
            guard success else {
                DispatchQueue.main.async {
                    self.message = error?.localizedDescription ?? "Unable to end HealthKit collection"
                    current.end()
                    self.reset()
                }
                return
            }
            collector.finishWorkout { saved, error in
                DispatchQueue.main.async {
                    self.message = saved != nil
                        ? "Workout saved to Apple Fitness"
                        : "Apple Fitness save failed: \(error?.localizedDescription ?? "Unknown error")"
                    current.end()
                    self.reset()
                }
            }
        }
    }

    private func reset() {
        isRunning = false
        isPaused = false
        ending = false
        session = nil
        builder = nil
        kind = nil
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo newState: HKWorkoutSessionState,
                        from oldState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async {
            switch newState {
            case .stopped:
                if self.ending { self.finishRecording(end: date) }
            case .paused:
                self.isPaused = true
            case .running:
                self.isPaused = false
            case .ended:
                self.isRunning = false
            default: break
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.message = error.localizedDescription
            self.reset()
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let heart = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let live = collectedTypes.contains(heart)
            ? workoutBuilder.statistics(for: heart)?.mostRecentQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            : nil
        let avg = collectedTypes.contains(heart)
            ? workoutBuilder.statistics(for: heart)?.averageQuantity()?
                .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            : nil
        let meters = collectedTypes.contains(distance)
            ? workoutBuilder.statistics(for: distance)?.sumQuantity()?
                .doubleValue(for: .meter())
            : nil

        DispatchQueue.main.async {
            if let live { self.heartRateBPM = live }
            if let avg { self.averageHeartRateBPM = avg }
            if let meters { self.distanceMeters = meters }
        }
    }
}
