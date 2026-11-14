import Foundation
import Combine
import HealthKit

/// Optional on-watch Apple Fitness workout recording.
/// Weight/repetition logging is independent and works if permission is denied.
final class WatchHealthSession: NSObject, ObservableObject,
                                HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    @Published private(set) var isRunning = false
    @Published private(set) var heartRateBPM: Double?
    @Published private(set) var message = "Fitness session not started"

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    func start() {
        guard HKHealthStore.isHealthDataAvailable() else {
            message = "HealthKit is unavailable on this watch."
            return
        }
        guard !isRunning else { return }

        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        store.requestAuthorization(toShare: [HKObjectType.workoutType()],
                                   read: [heartRateType]) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.message = "Health permission: \(error.localizedDescription)"
                    return
                }
                self.begin()
            }
        }
    }

    private func begin() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let current = try HKWorkoutSession(healthStore: store,
                                               configuration: configuration)
            let collector = current.associatedWorkoutBuilder()
            collector.dataSource = HKLiveWorkoutDataSource(
                healthStore: store, workoutConfiguration: configuration
            )
            current.delegate = self
            collector.delegate = self
            session = current
            builder = collector

            let now = Date()
            current.startActivity(with: now)
            collector.beginCollection(withStart: now) { [weak self] success, error in
                DispatchQueue.main.async {
                    self?.message = success ? "Apple Fitness strength workout recording"
                        : (error?.localizedDescription ?? "Could not start Fitness recording")
                    self?.isRunning = success
                }
            }
        } catch {
            message = "Workout start failed: \(error.localizedDescription)"
        }
    }

    func finish() {
        guard let current = session, let collector = builder else { return }
        isRunning = false
        current.end()
        collector.endCollection(withEnd: Date()) { [weak self] success, error in
            guard success else {
                DispatchQueue.main.async {
                    self?.message = error?.localizedDescription ?? "Unable to end collection"
                }
                return
            }
            collector.finishWorkout { _, error in
                DispatchQueue.main.async {
                    self?.message = error == nil ? "Workout saved to Apple Fitness"
                        : "Fitness save failed: \(error!.localizedDescription)"
                    self?.session = nil
                    self?.builder = nil
                }
            }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        DispatchQueue.main.async {
            if toState == .ended { self.isRunning = false }
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isRunning = false
            self.message = error.localizedDescription
        }
    }

    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        guard let heart = HKQuantityType.quantityType(forIdentifier: .heartRate),
              collectedTypes.contains(heart),
              let latest = workoutBuilder.statistics(for: heart)?.mostRecentQuantity()
        else { return }
        let bpm = latest.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        DispatchQueue.main.async { self.heartRateBPM = bpm }
    }
}
