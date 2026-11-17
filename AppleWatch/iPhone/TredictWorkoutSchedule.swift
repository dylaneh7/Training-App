import Foundation
import SwiftUI
import Combine
import Security
import CryptoKit
import HealthKit
import WorkoutKit

/// Running workouts from Tredict's read-only Personal API. All data stays
/// on this iPhone apart from Apple's local WorkoutKit schedule sync.
struct HCTredictPlannedRun: Identifiable, Hashable {
    struct Step: Hashable, Identifiable {
        let order: Int
        let phase: Phase
        let label: String
        let duration: Duration
        let heartRate: ClosedRange<Int>?
        var id: Int { order }
    }

    enum Phase: Hashable {
        case warmup, work, recovery, cooldown
    }
    enum Duration: Hashable {
        case seconds(Double), meters(Double), open
    }

    let id: String
    let date: String              // Tredict's calendar YYYY-MM-DD, not device timezone conversion
    let title: String
    let notes: String
    let steps: [Step]
    let unsupportedReason: String?
    let hasExecutedActivity: Bool

    var canSend: Bool {
        unsupportedReason == nil && !hasExecutedActivity && !steps.isEmpty
    }
    var detail: String {
        steps.map { step in
            let goal: String
            switch step.duration {
            case .seconds(let seconds):
                goal = "\(Int(seconds.rounded())) sec"
            case .meters(let meters):
                goal = String(format: "%.2f mi", meters / 1609.344)
            case .open: goal = "Open"
            }
            let heart = step.heartRate.map { " · \($0.lowerBound)–\($0.upperBound) bpm" } ?? ""
            return "\(step.label) · \(goal)\(heart)"
        }.joined(separator: "\n")
    }
}

private enum HCTredictScheduleError: LocalizedError {
    case noToken, forbidden, badResponse, unsupported, permission, limit, notConfirmed
    var errorDescription: String? {
        switch self {
        case .noToken: return "Connect Tredict in iMun Settings first."
        case .forbidden: return "Tredict access expired or lacks activityRead permission. Open Tredict and refresh its Personal API connection."
        case .badResponse: return "Tredict did not return a valid structured running plan."
        case .unsupported: return "This workout includes a step or target Apple Workout can't reproduce safely."
        case .permission: return "Allow iMun to add workouts in Apple Workout settings."
        case .limit: return "Apple Workout's scheduled-workout limit has been reached."
        case .notConfirmed: return "Workout was not confirmed on the Apple schedule; try again."
        }
    }
}

@MainActor
final class HCTredictWatchPlanSync: ObservableObject {
    @Published private(set) var runs: [HCTredictPlannedRun] = []
    @Published private(set) var loading = false
    @Published private(set) var sending = false
    @Published private(set) var status = "Connect Tredict to fetch structured running workouts."

    private static let tokenService = "imun.tredict.personal-api"

    var connected: Bool { Self.token() != nil }

    func refresh() {
        guard !loading else { return }
        guard let token = Self.token() else {
            status = "Connect Tredict in iMun Settings to load Garmin-style running steps."
            return
        }
        loading = true
        status = "Loading structured runs and heart-rate targets from Tredict…"
        Task {
            do {
                let incoming = try await Self.fetchUpcoming(token: token)
                self.runs = incoming
                let supported = incoming.filter(\.canSend).count
                self.status = "\(supported) ready to send · \(incoming.count) upcoming Tredict runs"
            } catch {
                // Never erase successfully fetched or scheduled plans on a network failure.
                self.status = "Tredict running plan: \(error.localizedDescription)"
            }
            loading = false
        }
    }

    func sendSelected(_ selectedIDs: Set<String>) {
        guard !sending else { return }
        let toSend = runs.filter { selectedIDs.contains($0.id) && $0.canSend }
        guard !toSend.isEmpty else {
            status = "Choose at least one supported, unfinished run to send."
            return
        }
        sending = true
        status = "Sending \(toSend.count) structured run(s) to Apple Workout…"
        Task {
            var sent = 0
            var unchanged = 0
            var failures: [String] = []
            for run in toSend {
                do {
                    let changed = try await Self.schedule(run)
                    if changed { sent += 1 } else { unchanged += 1 }
                } catch {
                    failures.append("\(run.title): \(error.localizedDescription)")
                }
            }
            status = "Apple Workout: \(sent) scheduled, \(unchanged) already current" +
                (failures.isEmpty ? "." : ". Could not send: " + failures.joined(separator: "; "))
            sending = false
        }
    }

    private static func token() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: "personal-api",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    private static func url(_ path: String, query: [URLQueryItem] = []) -> URL {
        var url = URLComponents(string: "https://www.tredict.com/api/oauth/v2/\(path)")!
        url.queryItems = query
        return url.url!
    }

    private static func api(_ url: URL, token: String) async throws -> [String: Any] {
        guard url.scheme == "https", url.host == "www.tredict.com",
              url.path.hasPrefix("/api/oauth/v2/") else {
            throw HCTredictScheduleError.badResponse
        }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let response = response as? HTTPURLResponse else {
            throw HCTredictScheduleError.badResponse
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw HCTredictScheduleError.forbidden
        }
        guard (200...299).contains(response.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HCTredictScheduleError.badResponse
        }
        return object
    }

    private static func utc(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func fetchUpcoming(token: String) async throws -> [HCTredictPlannedRun] {
        let now = Date()
        // Include a small edge buffer; filter by the Tredict calendar date below.
        let page = try await api(url("plannedTrainingList", query: [
            URLQueryItem(name: "startDate", value: utc(now.addingTimeInterval(-86400 * 2))),
            URLQueryItem(name: "endDate", value: utc(now.addingTimeInterval(86400 * 10))),
            URLQueryItem(name: "sportType", value: "running")
        ]), token: token)
        let embedded = page["_embedded"] as? [String: Any]
        let rows = embedded?["plannedWorkoutList"] as? [[String: Any]] ?? []
        let calendar = Calendar.current
        let today = HCPlanBuilder.dateString(now)
        let daySeven = calendar.date(byAdding: .day, value: 6,
                                      to: calendar.startOfDay(for: now)) ?? now
        let lastDay = HCPlanBuilder.dateString(daySeven)
        var result: [HCTredictPlannedRun] = []
        for row in rows {
            guard let id = row["id"] as? String,
                  id.range(of: "^[A-Za-z0-9]+$", options: .regularExpression) != nil,
                  let stamp = row["date"] as? String else { continue }
            // The API's date field is a calendar entry. Converting midnight
            // UTC to the phone's timezone can shift a prescribed run by a day.
            let day = String(stamp.prefix(10))
            guard day >= today && day <= lastDay else { continue }
            let displayTitle = row["title"] as? String ?? "Tredict Run"
            let hasExecuted = row["executedTrainingId"] as? String != nil
            // Keep the entry visible even if a step cannot be translated.
            do {
                let raw = try await api(url("plannedTraining/file/json/\(id)", query: [
                    URLQueryItem(name: "language", value: "en"),
                    URLQueryItem(name: "extraValues", value: "1")
                ]), token: token)
                let parsed = parseSteps(raw["steps"] as? [[String: Any]] ?? [])
                result.append(.init(id: id, date: day,
                    title: raw["workoutName"] as? String ?? displayTitle,
                    notes: raw["description"] as? String ?? row["notes"] as? String ?? "",
                    steps: parsed.steps, unsupportedReason: parsed.error,
                    hasExecutedActivity: hasExecuted))
            } catch {
                result.append(.init(id: id, date: day, title: displayTitle,
                    notes: row["notes"] as? String ?? "",
                    steps: [], unsupportedReason: error.localizedDescription,
                    hasExecutedActivity: hasExecuted))
            }
        }
        return result.sorted { $0.date == $1.date ? $0.title < $1.title : $0.date < $1.date }
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func parseSteps(_ raw: [[String: Any]])
        -> (steps: [HCTredictPlannedRun.Step], error: String?) {
        guard !raw.isEmpty else { return ([], "No structured steps supplied by Tredict") }
        var result: [HCTredictPlannedRun.Step] = []
        for (index, item) in raw.enumerated() {
            guard (item["type"] as? String ?? "WorkoutStep") == "WorkoutStep" else {
                return ([], "This workout uses a nested/repeating step format that needs another translator")
            }
            let intensity = (item["intensity"] as? String ?? "").uppercased()
            let phase: HCTredictPlannedRun.Phase
            switch intensity {
            case "WARMUP": phase = .warmup
            case "INTERVAL", "ACTIVE", "WORK": phase = .work
            case "RECOVERY", "REST": phase = .recovery
            case "COOLDOWN": phase = .cooldown
            default:
                return ([], "Unrecognized training intensity: \(intensity)")
            }
            let durationType = (item["durationType"] as? String ?? "").uppercased()
            let duration: HCTredictPlannedRun.Duration
            switch durationType {
            case "TIME":
                guard let seconds = number(item["durationValue"]),
                      seconds.isFinite, seconds > 0 else {
                    return ([], "Missing/invalid duration in interval \(index + 1)")
                }
                duration = .seconds(seconds)
            case "DISTANCE":
                guard let meters = number(item["durationValue"]),
                      meters.isFinite, meters > 0 else {
                    return ([], "Missing/invalid distance in interval \(index + 1)")
                }
                duration = .meters(meters)
            case "OPEN":
                duration = .open
            default:
                return ([], "Unsupported interval goal: \(durationType)")
            }
            let target = (item["targetType"] as? String ?? "").uppercased()
            let heartRate: ClosedRange<Int>?
            if target == "HEART_RATE" {
                guard let low = number(item["targetValueLow"]),
                      let high = number(item["targetValueHigh"]),
                      low.isFinite, high.isFinite,
                      (30...240).contains(low), (30...240).contains(high),
                      low <= high else {
                    return ([], "Invalid heart-rate targets in interval \(index + 1)")
                }
                heartRate = Int(low.rounded())...Int(high.rounded())
            } else if ["", "NONE", "OPEN"].contains(target) {
                heartRate = nil
            } else {
                return ([], "The \(target) target isn't supported by this Apple export yet")
            }
            result.append(.init(order: index, phase: phase,
                                label: item["description"] as? String ?? "Run",
                                duration: duration, heartRate: heartRate))
        }
        guard result.contains(where: { $0.phase == .work || $0.phase == .recovery }) else {
            return ([], "No runnable interval found")
        }
        guard result.filter({$0.phase == .warmup}).count <= 1,
              result.filter({$0.phase == .cooldown}).count <= 1,
              !result.enumerated().contains(where: { $0.element.phase == .warmup && $0.offset != 0 }),
              !result.enumerated().contains(where: { $0.element.phase == .cooldown && $0.offset != result.count - 1 })
        else {
            return ([], "Warm-up/cooldown steps need to be at their proper positions")
        }
        return (result, nil)
    }

    private static func workoutID(_ run: HCTredictPlannedRun) -> UUID {
        // SHA-256 provides the same UUID for the same Tredict source ID/date,
        // even if the app restarts or the remote workout is edited.
        let digest = SHA256.hash(data: Data("iMun-Tredict-WorkoutKit:\(run.id):\(run.date)".utf8))
        let bytes = Array(digest.prefix(16))
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],
                           bytes[4],bytes[5],bytes[6],bytes[7],
                           bytes[8],bytes[9],bytes[10],bytes[11],
                           bytes[12],bytes[13],bytes[14],bytes[15]))
    }

    private static func schedule(_ run: HCTredictPlannedRun) async throws -> Bool {
        guard run.canSend, WorkoutScheduler.isSupported else {
            throw HCTredictScheduleError.unsupported
        }
        let location: HKWorkoutSessionLocationType = .outdoor
        var warmup: WorkoutStep?
        var cooldown: WorkoutStep?
        var intervals: [IntervalStep] = []
        for segment in run.steps {
            let goal: WorkoutGoal
            switch segment.duration {
            case .seconds(let secs): goal = .time(secs, .seconds)
            case .meters(let meters): goal = .distance(meters, .meters)
            case .open: goal = .open
            }
            guard CustomWorkout.supportsGoal(goal, activity: .running, location: location) else {
                throw HCTredictScheduleError.unsupported
            }
            var alert: (any WorkoutAlert)?
            if let range = segment.heartRate {
                let target = HeartRateRangeAlert.heartRate(
                    Double(range.lowerBound)...Double(range.upperBound),
                    unit: WorkoutAlertMetric.countPerMinute)
                guard CustomWorkout.supportsAlert(target, activity: .running,
                                                  location: location) else {
                    throw HCTredictScheduleError.unsupported
                }
                alert = target
            }
            var step = WorkoutStep(goal: goal, alert: alert)
            if #available(iOS 18.0, *) {
                step.displayName = segment.label
            }
            switch segment.phase {
            case .warmup: warmup = step
            case .cooldown: cooldown = step
            case .work: intervals.append(IntervalStep(.work, step: step))
            case .recovery: intervals.append(IntervalStep(.recovery, step: step))
            }
        }
        let workout = CustomWorkout(activity: .running, location: location,
                                    displayName: run.title, warmup: warmup,
                                    blocks: [IntervalBlock(steps: intervals, iterations: 1)],
                                    cooldown: cooldown)
        let plan = WorkoutPlan(.custom(workout), id: workoutID(run))
        let scheduler = WorkoutScheduler.shared
        let current = await scheduler.authorizationState
        let authorization = current == .notDetermined
            ? await scheduler.requestAuthorization() : current
        guard authorization == .authorized else {
            throw HCTredictScheduleError.permission
        }
        let parts = run.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { throw HCTredictScheduleError.badResponse }
        let date = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        let existing = await scheduler.scheduledWorkouts
        let same = existing.filter { $0.plan.id == plan.id }
        if same.contains(where: {
            $0.date.year == date.year && $0.date.month == date.month &&
            $0.date.day == date.day && $0.plan == plan
        }) { return false }
        guard existing.count - same.count < WorkoutScheduler.maxAllowedScheduledWorkoutCount else {
            throw HCTredictScheduleError.limit
        }
        for item in same {
            await scheduler.remove(item.plan, at: item.date)
        }
        await scheduler.schedule(plan, at: date)
        let confirmed = await scheduler.scheduledWorkouts
        guard confirmed.contains(where: { $0.plan.id == plan.id &&
            $0.date.year == date.year && $0.date.month == date.month &&
            $0.date.day == date.day }) else {
            throw HCTredictScheduleError.notConfirmed
        }
        return true
    }
}
