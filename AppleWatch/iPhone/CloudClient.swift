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
            "source": "Apple Watch"
        ]
        body["weight_lb"] = set.weightLb.map { $0 as Any } ?? NSNull()
        body["rir"] = set.rir.map { $0 as Any } ?? NSNull()

        _ = try await send(path: "/rest/v1/health_coach_watch_sets",
                           query: [URLQueryItem(name: "on_conflict", value: "id")],
                           method: "POST", json: [body], bearer: authenticated.access,
                           prefer: "resolution=ignore-duplicates,return=minimal")
    }
}
