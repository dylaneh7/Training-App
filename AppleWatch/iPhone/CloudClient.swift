import Foundation
import Security

enum HCCloudError: LocalizedError {
    case notSignedIn
    case malformedResponse
    case server(String)
    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to Health Coach first."
        case .malformedResponse: return "Health Coach returned an unexpected response."
        case .server(let reason): return reason
        }
    }
}

struct HCAuthToken: Codable {
    let userID: String
    let access: String
    let refresh: String
    let expires: Date
}

private enum HCTokenVault {
    private static let service = "HealthCoachNative.Session"
    private static let account = "health-coach"

    static func load() -> HCAuthToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return try? JSONDecoder().decode(HCAuthToken.self, from: data)
    }

    static func save(_ token: HCAuthToken) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        remove()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Minimal native Supabase REST client, requiring no third-party packages.
/// Only the public publishable key is bundled. Credentials/tokens are stored
/// locally in Keychain; the user-scoped database operations enforce RLS.
actor HCCloudClient {
    private let root = URL(string: "https://ecmosmmqloyahsdcxvpz.supabase.co")!
    private let publishableKey = "sb_publishable_ClssY_cSAW7Lv7O2VG6jBg_yTDZW1fJ"
    private var token: HCAuthToken? = HCTokenVault.load()

    var signedInUserID: String? { token?.userID }

    func signIn(email: String, password: String) async throws -> String {
        let body = ["email": email, "password": password]
        let data = try await send(path: "/auth/v1/token", query: [
            URLQueryItem(name: "grant_type", value: "password")
        ], method: "POST", json: body, bearer: nil)
        let decoded = try decodeToken(data)
        token = decoded
        HCTokenVault.save(decoded)
        return decoded.userID
    }

    /// Authenticated call to a Supabase Edge Function. No AI provider key is
    /// present in the app. Context is supplied by the user with clear consent.
    func checkIMUNCoachAvailability() async throws -> String {
        let user = try await authorizedToken()
        let data = try await send(path: "/functions/v1/imun-ai-coach",
                                  bearer: user.access)
        guard let info = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ready = info["ready"] as? Bool else {
            throw HCCloudError.malformedResponse
        }
        if ready {
            return "Secure AI service ready"
        }
        throw HCCloudError.server(
            (info["message"] as? String) ?? "AI service needs server configuration"
        )
    }

    /// Distinct mode from the conversational Coach. The backend returns an
    /// action *proposal* in JSON; never executes a model-generated command.
    func classifyIMUNCoachAction(request: String, context: String) async throws -> String {
        let credentials = try await authorizedToken()
        let data = try await send(
            path: "/functions/v1/imun-ai-coach",
            method: "POST",
            json: [
                "mode": "proposeAction",
                "question": String(request.prefix(800)),
                "context": String(context.prefix(2200)),
                "shareRecovery": false
            ],
            bearer: credentials.access)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let reply = object?["reply"] as? String else {
            throw HCCloudError.malformedResponse
        }
        return reply
    }

    func askIMUNCoach(question: String, context: String,
                      shareRecovery: Bool,
                      attachments: [IMUNCoachAttachment] = []) async throws -> String {
        let authenticated = try await authorizedToken()
        let data = try await send(path: "/functions/v1/imun-ai-coach",
                                  method: "POST",
                                  json: ["question": String(question.prefix(1500)),
                                         "context": String(context.prefix(24_000)),
                                         "shareRecovery": shareRecovery,
                                         "attachments": attachments.prefix(4)
                                             .map(\.requestPayload)],
                                  bearer: authenticated.access)
        guard let output = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let reply = output["reply"] as? String,
              !reply.isEmpty else { throw HCCloudError.malformedResponse }
        return reply
    }

    func signOut() {
        token = nil
        HCTokenVault.remove()
    }

    private func decodeToken(_ data: Data) throws -> HCAuthToken {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = object["access_token"] as? String,
              let refresh = object["refresh_token"] as? String,
              let user = object["user"] as? [String: Any],
              let userID = user["id"] as? String
        else { throw HCCloudError.malformedResponse }
        let ttl = (object["expires_in"] as? NSNumber)?.doubleValue ?? 3600
        return HCAuthToken(userID: userID, access: access, refresh: refresh,
                           expires: Date().addingTimeInterval(ttl))
    }

    private func authorizedToken() async throws -> HCAuthToken {
        guard let current = token else { throw HCCloudError.notSignedIn }
        if current.expires > Date().addingTimeInterval(60) { return current }
        let data = try await send(path: "/auth/v1/token", query: [
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ], method: "POST", json: ["refresh_token": current.refresh], bearer: nil)
        let updated = try decodeToken(data)
        token = updated
        HCTokenVault.save(updated)
        return updated
    }

    private func send(path: String, query: [URLQueryItem] = [],
                      method: String = "GET", json: Any? = nil,
                      bearer: String?, prefer: String? = nil) async throws -> Data {
        var components = URLComponents(url: root.appendingPathComponent(String(path.dropFirst())),
                                       resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw HCCloudError.malformedResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [.fragmentsAllowed])
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HCCloudError.malformedResponse }
        if !(200...299).contains(http.statusCode) {
            let value = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let message = (value?["msg"] as? String)
                ?? (value?["error_description"] as? String)
                ?? (value?["message"] as? String)
                ?? (value?["error"] as? String)
                ?? "Cloud request failed (HTTP \(http.statusCode))."
            throw HCCloudError.server(message)
        }
        return data
    }

    private func getState(table: String) async throws -> [String: Any] {
        let authenticated = try await authorizedToken()
        let data = try await send(path: "/rest/v1/\(table)", query: [
            URLQueryItem(name: "select", value: "data"),
            URLQueryItem(name: "user_id", value: "eq.\(authenticated.userID)"),
            URLQueryItem(name: "limit", value: "1")
        ], bearer: authenticated.access)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw HCCloudError.malformedResponse }
        return rows.first?["data"] as? [String: Any] ?? [:]
    }

    func fetchPlannerAndHistory() async throws -> (planner: [String: Any], history: [String: Any]) {
        // Sequential for predictable refresh-token behavior.
        let planner = try await getState(table: "planner_state")
        let history = try await getState(table: "hybrid_coach_state")
        return (planner, history)
    }

    /// A single atomic user-scoped snapshot for iMun Watch. Running and
    /// strength share the same date and source; this never records a workout.
    func publishWatchSchedule(_ schedule: HCWatchSchedule) async throws {
        let session = try await authorizedToken()
        let bytes = try JSONEncoder().encode(schedule)
        guard let snapshot = try JSONSerialization.jsonObject(with: bytes)
                as? [String: Any] else {
            throw HCCloudError.malformedResponse
        }
        let data = try await send(
            path: "/rest/v1/health_coach_watch_schedules",
            query: [URLQueryItem(name: "on_conflict", value: "user_id,workout_date")],
            method: "POST",
            json: [[
                "user_id": session.userID,
                "workout_date": schedule.date,
                "schedule": snapshot,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]],
            bearer: session.access,
            prefer: "resolution=merge-duplicates,return=representation")
        // A successful HTTP status alone isn't confirmation of a row: RLS
        // or configuration may silently return an empty representation.
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              rows.count == 1, rows[0]["workout_date"] as? String == schedule.date
        else { throw HCCloudError.malformedResponse }
    }

    /// Optional EITAN bridge for an athlete's independently authenticated
    /// Apple Watch. Only runs after explicit EITAN cloud consent. This is
    /// derived health information and must NEVER be attached to the workout
    /// schedule or enabled implicitly by ordinary account sign-in.
    func publishEitanForWatch(_ snapshot: HCEitanSnapshot?,
                              enabled: Bool) async throws {
        let session = try await authorizedToken()
        let json: Any
        if enabled, let snapshot {
            let bytes = try JSONEncoder().encode(snapshot)
            guard bytes.count < 32_000,
                  let dictionary = try JSONSerialization.jsonObject(
                    with: bytes) as? [String: Any] else {
                throw HCCloudError.malformedResponse
            }
            json = dictionary
        } else {
            json = NSNull()
        }
        let date = enabled ? snapshot?.date : nil
        let response = try await send(
            path: "/rest/v1/health_coach_eitan_snapshots",
            query: [URLQueryItem(name: "on_conflict", value: "user_id")],
            method: "POST",
            json: [[
                "user_id": session.userID,
                "score_date": date as Any? ?? NSNull(),
                "enabled": enabled,
                "snapshot": json,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]],
            bearer: session.access,
            prefer: "resolution=merge-duplicates,return=representation")
        guard let rows = try JSONSerialization.jsonObject(with: response)
                as? [[String: Any]],
              rows.count == 1,
              rows[0]["enabled"] as? Bool == enabled else {
            throw HCCloudError.malformedResponse
        }
    }

    func fetchPublishedPlan(date: String) async throws -> HCWorkout? {
        let authenticated = try await authorizedToken()
        let data = try await send(path: "/rest/v1/health_coach_native_plans",
                                  query: [
                                    URLQueryItem(name: "select", value: "plan"),
                                    URLQueryItem(name: "user_id", value: "eq.\(authenticated.userID)"),
                                    URLQueryItem(name: "workout_date", value: "eq.\(date)"),
                                    URLQueryItem(name: "limit", value: "1")
                                  ], bearer: authenticated.access)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw HCCloudError.malformedResponse }
        guard let plan = rows.first?["plan"] as? [String: Any] else { return nil }
        let bytes = try JSONSerialization.data(withJSONObject: plan)
        return try JSONDecoder().decode(HCWorkout.self, from: bytes)
    }

    /// Persist only user-approved visual preferences. RLS ensures the Watch
    /// signed into this same account can read them independently.
    func saveVisualPreferences(_ design: [String: Any]) async throws {
        let current = try await authorizedToken()
        _ = try await send(
            path: "/rest/v1/health_coach_visual_preferences",
            query: [URLQueryItem(name: "on_conflict", value: "user_id")],
            method: "POST",
            json: [[
                "user_id": current.userID,
                "design": design,
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ]],
            bearer: current.access,
            prefer: "resolution=merge-duplicates,return=minimal")
    }

    /// Atomically moves one existing planner workout without rewriting the
    /// user's full calendar from a potentially stale iPhone snapshot.
    func movePlannedWorkout(id: String, to date: String) async throws {
        guard UUID(uuidString: id) != nil,
              HCPlanBuilder.startOfDate(date) != nil else {
            throw HCCloudError.server("Choose a valid saved workout and date.")
        }
        let authenticated = try await authorizedToken()
        let bytes = try await send(path: "/rest/v1/rpc/imun_move_planned_workout",
                                   method: "POST",
                                   json: ["p_item_id": id, "p_new_date": date],
                                   bearer: authenticated.access)
        let changed = (try? JSONSerialization.jsonObject(with: bytes, options: .fragmentsAllowed)) as? Bool
        guard changed == true else {
            throw HCCloudError.server("This workout could not be moved. Refresh the plan and try again.")
        }
    }

    /// User-confirmed completion marker on a real planner event. No recorded
    /// sets, GPS, HR or activity measurements are manufactured by this RPC.
    func markPlannedWorkoutComplete(id: String) async throws {
        guard UUID(uuidString: id) != nil else {
            throw HCCloudError.server("Choose a saved calendar workout. Rotation previews must be scheduled first.")
        }
        let authenticated = try await authorizedToken()
        let body = try await send(path: "/rest/v1/rpc/imun_mark_planned_workout_complete",
                                  method: "POST",
                                  json: ["p_item_id": id, "p_completed": true],
                                  bearer: authenticated.access)
        let changed = (try? JSONSerialization.jsonObject(
            with: body, options: .fragmentsAllowed)) as? Bool
        guard changed == true else {
            throw HCCloudError.server("The selected workout could not be marked complete. Refresh your calendar.")
        }
    }

    /// Move an unsaved day in the saved strength rotation. This writes a real
    /// planner event with a preserved original template date, suppressing the
    /// automatic copy on the old day. It never edits historical completed sets.
    func moveRotationWorkout(originalDate: String, to date: String,
                             title: String) async throws {
        guard HCPlanBuilder.startOfDate(originalDate) != nil,
              HCPlanBuilder.startOfDate(date) != nil,
              originalDate != date else {
            throw HCCloudError.server("Choose a different valid workout day.")
        }
        let authenticated = try await authorizedToken()
        let bytes = try await send(path: "/rest/v1/rpc/imun_move_rotation_workout",
                                   method: "POST",
                                   json: ["p_original_date": originalDate,
                                          "p_new_date": date,
                                          "p_title": title],
                                   bearer: authenticated.access)
        let changed = (try? JSONSerialization.jsonObject(
            with: bytes, options: .fragmentsAllowed)) as? Bool
        guard changed == true else {
            throw HCCloudError.server("This strength session already has a date or the destination is occupied.")
        }
    }

    /// Existing completed workouts are preserved with their original source.
    /// Tredict entries include Garmin-synced sessions already in Command Center.
    func fetchActivityHistory() async throws -> [HCTrainingActivity] {
        let rows = try await readRows("workout_completion_events",
            fields: "id,workout_date,workout_kind,title,source,external_id,activity_distance_m,activity_duration_sec,activity_duration_total_sec,activity_avg_hr,activity_max_hr,activity_calories,activity_pace_sec_km,activity_rpe,activity_enjoyment,activity_attribution",
            otherQuery: [URLQueryItem(name: "order", value: "workout_date.desc")],limit:1500)
        return rows.compactMap { row in
            guard let id = row["id"] as? String,
                  let date = row["workout_date"] as? String else { return nil }
            var activity = HCTrainingActivity(
                id: id, date: date,
                title: row["title"] as? String ?? "Workout",
                kind: row["workout_kind"] as? String ?? "other",
                source: row["source"] as? String ?? "Recorded",
                distanceMeters: numeric(row["activity_distance_m"]),
                durationSeconds: numeric(row["activity_duration_sec"]),
                averageBPM: numeric(row["activity_avg_hr"]),
                maxBPM: numeric(row["activity_max_hr"]),
                calories: numeric(row["activity_calories"]),
                perceivedEffort: numeric(row["activity_rpe"]))
            activity.totalDurationSeconds = numeric(row["activity_duration_total_sec"])
            activity.paceSecondsPerKm = numeric(row["activity_pace_sec_km"])
            activity.enjoyment = numeric(row["activity_enjoyment"])
            activity.attribution = row["activity_attribution"] as? String
            activity.externalID = row["external_id"] as? String
            return activity
        }
    }

    func saveWorkout(_ workout: HCWorkout) async throws {
        let authenticated = try await authorizedToken()
        let bytes = try JSONEncoder().encode(workout)
        guard var plan = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        else { throw HCCloudError.malformedResponse }
        plan["lastEditedBy"] = "iPhone"
        _ = try await send(path: "/rest/v1/health_coach_native_plans",
                           query: [URLQueryItem(name: "on_conflict", value: "user_id,workout_date")],
                           method: "POST",
                           json: [[
                             "user_id": authenticated.userID,
                             "workout_date": workout.date,
                             "plan": plan,
                             "updated_at": ISO8601DateFormatter().string(from: Date())
                           ]],
                           bearer: authenticated.access,
                           prefer: "resolution=merge-duplicates,return=minimal")
    }

    private func readRows(_ table: String, fields: String, otherQuery: [URLQueryItem] = [],
                          limit: Int = 500) async throws -> [[String: Any]] {
        let authenticated = try await authorizedToken()
        let data = try await send(path: "/rest/v1/\(table)", query: [
            URLQueryItem(name: "select", value: fields),
            URLQueryItem(name: "user_id", value: "eq.\(authenticated.userID)"),
            URLQueryItem(name: "limit", value: String(limit))
        ] + otherQuery, bearer: authenticated.access)
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw HCCloudError.malformedResponse }
        return rows
    }

    private func numeric(_ x: Any?) -> Double? {
        if let n = x as? NSNumber { return n.doubleValue }
        if let s = x as? String { return Double(s) }
        return nil
    }

    /// Read current-day set records from both iPhone and Watch. The
    /// authenticated user filter plus RLS protect the private history.
    func fetchCompletedSets(for workout: HCWorkout) async throws -> [HCLoggedSet] {
        let rows = try await readRows("health_coach_watch_sets",
            fields: "id,workout_date,session_key,workout_title,exercise_id,exercise_name,exercise_index,set_index,weight_lb,reps,rir,completed_at,started_at,duration_seconds,source,working_side,motion_insight",
            otherQuery: [
                URLQueryItem(name: "workout_date", value: "eq." + workout.date),
                URLQueryItem(name: "session_key", value: "eq." + workout.sessionKey)
            ], limit: 500)
        return HCSetReconciliation.decodeCloudRows(rows, workout: workout)
    }

    /// Read only signed-in athlete's undone set/session windows. Raw records
    /// are never used in progress after these corrections have arrived.
    func fetchWorkoutUndos(for workout: HCWorkout) async throws -> [HCWorkoutUndo] {
        let rows = try await readRows("health_coach_workout_undos",
            fields: "id,kind,set_id,workout_date,session_key,window_started_at,window_ended_at,created_at",
            otherQuery: [
                URLQueryItem(name: "workout_date", value: "eq." + workout.date),
                URLQueryItem(name: "session_key", value: "eq." + workout.sessionKey)
            ], limit: 500)
        return HCWorkoutUndo.decodeCloudRows(rows)
    }

    /// Idempotent user-scoped undo RPC. It atomically records a correction
    /// and removes matching server sets; the DB blocks late retransmissions.
    func recordWorkoutUndo(_ correction: HCWorkoutUndo) async throws {
        let credentials = try await authorizedToken()
        let response = try await send(path: "/rest/v1/rpc/imun_undo_workout_record",
                                      method: "POST",
                                      json: correction.apiPayload,
                                      bearer: credentials.access)
        guard let confirmed = (try? JSONSerialization.jsonObject(
            with: response, options: .fragmentsAllowed)) as? Bool,
              confirmed else {
            throw HCCloudError.malformedResponse
        }
    }

    func fetchWatchPerformance(before: String) async throws -> [HCPerformanceSet] {
        let rows = try await readRows("health_coach_watch_sets",
            fields: "exercise_name,weight_lb,reps,rir,workout_date",
            otherQuery: [
                URLQueryItem(name: "workout_date", value: "lt.\(before)"),
                URLQueryItem(name: "order", value: "workout_date.desc")
            ])
        return rows.compactMap { x -> HCPerformanceSet? in
            guard let name = x["exercise_name"] as? String,
                  let w = numeric(x["weight_lb"]), w > 0,
                  let reps = numeric(x["reps"]), reps > 0,
                  let date = x["workout_date"] as? String else { return nil }
            return .init(exercise:name,weightLb:w,reps:Int(reps),
                         rir:numeric(x["rir"]),date:date,source:"IMUN / Watch")
        }
    }

    func fetchRunHistory() async throws -> [HCProgressRun] {
        let old = try await readRows("workout_completion_events",
            fields: "id,workout_date,title,source,activity_started_at,activity_distance_m,activity_duration_sec,activity_avg_hr,activity_max_hr,activity_calories",
            otherQuery: [
                URLQueryItem(name: "workout_kind", value: "eq.run"),
                URLQueryItem(name: "order", value: "workout_date.desc")
            ])
        let watch = try await readRows("health_coach_native_runs",
            fields: "id,workout_date,distance_meters,started_at,ended_at,avg_heart_rate_bpm,source,splits",
            otherQuery: [URLQueryItem(name: "order", value: "workout_date.desc")])
        let converted: [HCProgressRun] = old.compactMap { x in
            guard let date = x["workout_date"] as? String,
                  let id = x["id"] as? String else { return nil }
            var run = HCProgressRun(id:id,date:date,title:x["title"] as? String ?? "Run",
                source:x["source"] as? String ?? "Connected service",
                distanceMeters:numeric(x["activity_distance_m"]),
                durationSeconds:numeric(x["activity_duration_sec"]),
                averageBPM:numeric(x["activity_avg_hr"]),splits:[])
            run.maxBPM = numeric(x["activity_max_hr"])
            run.activeCalories = numeric(x["activity_calories"])
            if let started = x["activity_started_at"] as? String {
                let iso = ISO8601DateFormatter()
                iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                run.startedAt = iso.date(from: started)
                    ?? ISO8601DateFormatter().date(from: started)
            }
            return run
        }
        let native: [HCProgressRun] = watch.compactMap { x in
            guard let date = x["workout_date"] as? String,
                  let id = x["id"] as? String else { return nil }
            let started = (x["started_at"] as? String).flatMap { ISO8601DateFormatter().date(from:$0) }
            let ended = (x["ended_at"] as? String).flatMap { ISO8601DateFormatter().date(from:$0) }
            let splits = ((x["splits"] as? [[String: Any]]) ?? []).enumerated().map { i, lap in
                HCRunSplit(index:i+1,
                           elapsedSeconds:numeric(lap["elapsedSeconds"]) ?? 0,
                           distanceMeters:numeric(lap["distanceMeters"]))
            }
            return HCProgressRun(id:id,date:date,title:"Apple Watch Run",
                source:x["source"] as? String ?? "Apple Watch",
                distanceMeters:numeric(x["distance_meters"]),
                durationSeconds:started != nil && ended != nil ? ended!.timeIntervalSince(started!) : nil,
                averageBPM:numeric(x["avg_heart_rate_bpm"]),splits:splits)
        }
        // Both Apple Watch and an imported provider may describe the same run.
        var unique:[HCProgressRun]=[]
        for x in (native+converted).sorted(by:{$0.date > $1.date}) {
            let duplicate=unique.contains { other in
                other.date==x.date && other.distanceMeters != nil && x.distanceMeters != nil
                  && abs(other.distanceMeters!-x.distanceMeters!) < 150
                  && abs((other.durationSeconds ?? 0)-(x.durationSeconds ?? 0)) < 90
            }
            if !duplicate {unique.append(x)}
        }
        return unique
    }

    func fetchRecoveryHistory() async throws -> [HCRecoveryDatum] {
        let rows=try await readRows("recovery_daily_metrics",
            fields:"metric_date,sleep_seconds,hrv_ms,hrv_baseline_ms,daily_low_hr_bpm,source",
            otherQuery:[URLQueryItem(name:"order",value:"metric_date.desc")],limit:120)
        return rows.compactMap { x in
            guard let date=x["metric_date"] as? String else{return nil}
            return HCRecoveryDatum(date:date,sleepSeconds:numeric(x["sleep_seconds"]),
                                   hrvMS:numeric(x["hrv_ms"]),hrvBaselineMS:numeric(x["hrv_baseline_ms"]),
                                   dailyLowHR:numeric(x["daily_low_hr_bpm"]),
                                   source:x["source"] as? String ?? "Tredict")
        }
    }

    func upload(_ run: HCRunFinished) async throws {
        let authenticated=try await authorizedToken()
        let iso=ISO8601DateFormatter()
        iso.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let rows=run.splits.map {[
            "index":$0.index,
            "elapsedSeconds":$0.elapsedSeconds,
            "distanceMeters":$0.distanceMeters.map{$0 as Any} ?? NSNull()
        ]}
        _ = try await send(path:"/rest/v1/health_coach_native_runs",
            query:[URLQueryItem(name:"on_conflict",value:"id")],
            method:"POST",json:[[ "id":run.id.uuidString.lowercased(),
                "user_id":authenticated.userID,
                "plan_id":run.planID.map{$0 as Any} ?? NSNull(),
                "workout_date":run.date,
                "started_at":iso.string(from:run.startedAt),
                "ended_at":iso.string(from:run.endedAt),
                "distance_meters":run.distanceMeters.map{$0 as Any} ?? NSNull(),
                "avg_heart_rate_bpm":run.averageHeartRate.map{$0 as Any} ?? NSNull(),
                "splits":rows,"source":"Apple Watch"
            ]],bearer:authenticated.access,
            prefer:"resolution=ignore-duplicates,return=minimal")
    }

    func upload(_ set: HCLoggedSet) async throws {
        let authenticated = try await authorizedToken()
        let stamp = ISO8601DateFormatter()
        stamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var body: [String: Any] = [
            "id": set.id.uuidString.lowercased(),
            "user_id": authenticated.userID,
            "workout_date": set.workoutDate,
            "session_key": set.sessionKey,
            "workout_title": set.workoutTitle,
            "exercise_id": set.exerciseID,
            "exercise_name": set.exerciseName,
            "exercise_index": set.exerciseIndex,
            "set_index": set.index,
            "reps": set.reps,
            "completed_at": stamp.string(from: set.completedAt),
            "source": set.source ?? "Apple Watch"
        ]
        body["weight_lb"] = set.weightLb.map { $0 as Any } ?? NSNull()
        body["rir"] = set.rir.map { $0 as Any } ?? NSNull()
        body["started_at"] = set.startedAt.map { stamp.string(from:$0) as Any } ?? NSNull()
        body["duration_seconds"] = set.durationSeconds.map { $0 as Any } ?? NSNull()
        body["working_side"] = set.side.map { $0.rawValue as Any } ?? NSNull()
        if let insight = set.motionInsight,
           let data = try? JSONEncoder().encode(insight),
           let object = try? JSONSerialization.jsonObject(with: data) {
            body["motion_insight"] = object
        }


        _ = try await send(path: "/rest/v1/health_coach_watch_sets",
                           query: [URLQueryItem(name: "on_conflict", value: "id")],
                           method: "POST", json: [body], bearer: authenticated.access,
                           prefer: "resolution=merge-duplicates,return=minimal")
    }
}
