import SwiftUI
import WidgetKit
import ActivityKit

/// The widget is a read-only copy of locally available records. Workout
/// information is always okay to share; personal health readings are opt-in.
@MainActor
enum IMUNWidgetPublisher {
    private static var lastFingerprint = ""

    static func publish(coach: PhoneWorkoutBridge,
                        health: HCAppleHealthReader,
                        allowHealth: Bool) {
        guard let defaults = UserDefaults(suiteName: IMUNWidgetKeys.suite) else { return }
        let today = HCPlanBuilder.dateString(Date())
        let lift = coach.workout.flatMap {
            $0.date == today && !$0.exercises.isEmpty ? $0 : nil
        }
        let run = coach.runPlan.flatMap {
            $0.date == today && !$0.isCompleted ? $0 : nil
        }
        let title = lift?.title ?? run?.title ?? "No training scheduled"
        let progress = lift.map {
            "\(coach.completedSets(for: $0).count)/\($0.prescribedSetCount)"
        } ?? "—"
        let running = run?.title ?? ""
        let values = health.metrics
        func best(_ terms: [String]) -> HCHealthMetric? {
            values.filter { metric in
                terms.contains { metric.name.localizedCaseInsensitiveContains($0) }
            }.sorted { $0.date > $1.date }.first
        }
        let sleep = allowHealth ? best(["Total asleep"]) : nil
        let hrv = allowHealth ? best(["HRV", "Heart rate variability"]) : nil
        let source = (sleep ?? hrv).map { $0.source + " · " + $0.date }

        // Check for an identical payload before telling WidgetKit to refresh.
        let fingerprint = [title, progress, running, sleep?.value ?? "",
                           hrv?.value ?? "", source ?? "", String(allowHealth), today]
            .joined(separator: "|")
        guard fingerprint != lastFingerprint else { return }
        lastFingerprint = fingerprint
        defaults.set(title, forKey: IMUNWidgetKeys.workout)
        defaults.set(progress, forKey: IMUNWidgetKeys.progress)
        defaults.set(running, forKey: IMUNWidgetKeys.running)
        defaults.set(today, forKey: IMUNWidgetKeys.date)
        defaults.set(allowHealth, forKey: IMUNWidgetKeys.healthEnabled)
        if allowHealth {
            defaults.set(sleep?.value, forKey: IMUNWidgetKeys.sleep)
            defaults.set(hrv?.value, forKey: IMUNWidgetKeys.hrv)
            defaults.set(source, forKey: IMUNWidgetKeys.source)
        } else {
            for key in [IMUNWidgetKeys.sleep, IMUNWidgetKeys.hrv,
                        IMUNWidgetKeys.source] {
                defaults.removeObject(forKey: key)
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: IMUNWidgetKeys.kind)
    }
}

@MainActor
enum IMUNLiveWorkoutController {
    private static var lastState = ""

    static func synchronize(coach: PhoneWorkoutBridge, enabled: Bool) {
        let active = Activity<IMUNWorkoutActivityAttributes>.activities
        if !enabled {
            lastState = ""
            for activity in active {
                Task { await activity.end(nil, dismissalPolicy: .immediate) }
            }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard let started = coach.activeWorkoutStartedAt else {
            lastState = ""
            for activity in active {
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
            return
        }
        let workout = coach.workout
        let completed = workout.map { coach.completedSets(for: $0).count } ?? 0
        let planned = workout?.prescribedSetCount ?? 0
        let title = workout?.title ?? "Strength training"
        let rest = coach.phoneRestEndsAt
        let fingerprint = [title, String(completed), String(planned),
                           rest.map { String($0.timeIntervalSince1970) } ?? "",
                           String(coach.cloudPendingCount)].joined(separator: "|")
        guard fingerprint != lastState || active.isEmpty else { return }
        lastState = fingerprint

        let state = IMUNWorkoutActivityAttributes.ContentState(
            completedSets: completed,
            plannedSets: planned,
            restEnd: rest,
            syncPending: coach.cloudPendingCount
        )
        if let existing = active.first {
            Task {
                await existing.update(ActivityContent(state: state, staleDate: nil))
            }
        } else {
            // The iOS permission/foreground checks are enforced by ActivityKit.
            // Failure is nonfatal and never interrupts workout logging.
            let attributes = IMUNWorkoutActivityAttributes(
                workoutTitle: title, startedAt: started
            )
            do {
                _ = try Activity<IMUNWorkoutActivityAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } catch {
                lastState = ""
            }
        }
    }
}
