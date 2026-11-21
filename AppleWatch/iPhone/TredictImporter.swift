import Foundation
import Combine
import Security

/// Direct, read-only Tredict Personal API integration for the user's own data.
/// No Tredict token or downloaded activity is uploaded to Command Center.
/// Credentials are kept solely in iPhone Keychain.
struct HCTredictSnapshot: Codable {
    var activities: [HCTrainingActivity] = []
    var runs: [HCProgressRun] = []
    var recovery: [HCRecoveryDatum] = []
    var lastSync: Date? = nil
    var rawActivityCount = 0
    var dataTypes: [String] = []
}

final class HCTredictImporter: ObservableObject {
    @Published private(set) var snapshot = HCTredictSnapshot()
    @Published private(set) var connected = false
    @Published private(set) var loading = false
    @Published private(set) var status = "Connect Tredict to import your Garmin history."

    private static let tokenService = "imun.tredict.personal-api"
    private let documentName = "imun-tredict-snapshot.json"
    private let archiveName = "imun-tredict-original-data.json"

    init() {
        connected = Self.token() != nil
        if let path = fileURL(documentName),
           let data = try? Data(contentsOf: path),
           let cached = try? JSONDecoder().decode(HCTredictSnapshot.self, from: data) {
            snapshot = cached
            status = "Tredict: \(cached.rawActivityCount) activities available from your last import."
        }
    }

    var archiveURL: URL? {
        guard let url = fileURL(archiveName),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func fileURL(_ name: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask).first?.appendingPathComponent(name)
    }

    private static func token() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: "personal-api",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let bytes = out as? Data,
              let token = String(data: bytes, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    private static func writeToken(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: "personal-api"
        ]
        SecItemDelete(query as CFDictionary)
        let add = query.merging([
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String:
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]) { _, newer in newer }
        SecItemAdd(add as CFDictionary, nil)
    }

    func connect(token entered: String) {
        let clean = entered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 20, !clean.contains(where: { $0.isWhitespace }) else {
            status = "Paste your Tredict Personal API token. Don't share it in chat."
            return
        }
        Self.writeToken(clean)
        connected = true
        refresh()
    }

    func disconnect() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.tokenService,
            kSecAttrAccount as String: "personal-api"
        ]
        SecItemDelete(query as CFDictionary)
        connected = false
        loading = false
        status = "Tredict disconnected. Previous imports remain saved on this iPhone."
    }

    func refresh() {
        guard !loading, let token = Self.token() else {
            if !loading { status = "Connect your Tredict token first." }
            return
        }
        loading = true
        status = "Reading Tredict activity history…"
        Task {
            do {
                let imported = try await Self.fetchAll(token: token)
                let normalized = imported.snapshot
                DispatchQueue.main.async {
                    self.snapshot = normalized
                    self.loading = false
                    self.status = "Imported \(normalized.activities.count) Tredict sessions and \(normalized.recovery.count) recovery days."
                    if let url = self.fileURL(self.documentName),
                       let bytes = try? JSONEncoder().encode(normalized) {
                        try? bytes.write(to: url, options: .atomic)
                        self.protect(url)
                    }
                    if let url = self.fileURL(self.archiveName),
                       JSONSerialization.isValidJSONObject(imported.raw),
                       let bytes = try? JSONSerialization.data(withJSONObject: imported.raw,
                                                                options: [.sortedKeys]) {
                        try? bytes.write(to: url, options: .atomic)
                        self.protect(url)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.loading = false
                    self.status = "Tredict import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func protect(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path)
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private static func dateString(_ value: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: value)
            ?? ISO8601DateFormatter().date(from: value)
        if let date {
            return HCPlanBuilder.dateString(date)
        }
        return String(value.prefix(10))
    }


    private static func isoDate(_ value: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return precise.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    /// The Personal API can expose real Garmin/Tredict running dynamics and
    /// device laps. Only explicitly labeled measurements are normalized.
    private static func enrichRun(_ run: inout HCProgressRun,
                                  detail: [String: Any]) {
        let summary = detail["summary"] as? [String: Any] ?? [:]
        let gct = number(summary["groundContactTime"])
        if let gct, (90...600).contains(gct) {
            run.averageGroundContactTimeMS = gct
        }
        let step = number(summary["stepLength"])
        if let step, (0.3...3.5).contains(step) {
            run.averageStrideLengthMeters = step
        }
        let speed = number(summary["speed"])
        if let speed, (0.5...15).contains(speed) {
            run.averageRunningSpeedMPS = speed
        }
        // Tredict may return vertical oscillation in different provider
        // representations; do not guess a centimetre conversion from a
        // semantically undocumented numeric field.
        if run.averagePowerWatts == nil {
            run.averagePowerWatts = number(summary["power"])
        }
        if run.averageCadenceSPM == nil {
            run.averageCadenceSPM = number(summary["cadence"])
        }
        if let laps = detail["laps"] as? [[String: Any]] {
            var converted: [HCRunSplit] = []
            for lap in laps.prefix(300) {
                guard let duration = number(lap["duration"]),
                      duration >= 1 && duration <= 14400 else { continue }
                converted.append(HCRunSplit(index: converted.count + 1,
                    elapsedSeconds: duration,
                    distanceMeters: number(lap["distance"])))
            }
            if !converted.isEmpty {
                // Explicit laps (recorded or Tredict-constructed) are labeled
                // as Tredict laps in the Run Details provenance.
                run.splits = converted
            }
        }
        guard let series = detail["seriesSampled"] as? [String: Any],
              let raw = series["data"] as? [String: Any],
              let strideSeconds = number(series["sampleSize"]),
              strideSeconds >= 1 && strideSeconds <= 120,
              let timestamp = detail["date"] as? String,
              let started = isoDate(timestamp) else { return }
        run.startedAt = started
        if let duration = run.durationSeconds {
            run.endedAt = started.addingTimeInterval(duration)
        }
        let kinds: [(source: String, destination: String, low: Double, high: Double)] = [
            ("speed", "runningSpeed", 0.5, 15),
            ("speedGradeAdjusted", "runningGradeAdjustedSpeed", 0.5, 15),
            ("power", "runningPower", 1, 1500),
            ("powerOEM", "runningPowerWatch", 1, 1500),
            ("cadence", "runningCadence", 80, 260),
            ("groundContactTime", "runningGroundContactTime", 90, 600),
            ("stepLength", "runningStrideLength", 0.3, 3.5),
            ("verticalOscillation", "providerVerticalOscillation", 0.01, 500),
            ("verticalOscillationOEM", "providerWatchVerticalOscillation", 0.01, 500),
            ("flightTime", "providerFlightTime", 0.01, 500),
            ("formPower", "providerFormPower", 0.01, 1500),
            ("grade", "runningSourceGrade", -40, 40),
            ("temperature", "runningSourceTemperature", -40, 80),
            ("altitude", "runningAltitude", -500, 9000)
        ]
        var chart: [HCRunSensorReading] = []
        for item in kinds {
            guard let values = raw[item.source] as? [Any], !values.isEmpty else {
                continue
            }
            let stride = max(1, Int(ceil(Double(values.count) / 480)))
            for index in Swift.stride(from: 0, to: values.count, by: stride) {
                guard let value = number(values[index]), value.isFinite,
                      (item.low...item.high).contains(value) else { continue }
                chart.append(HCRunSensorReading(kind: item.destination,
                    at: started.addingTimeInterval(
                        Double(index) * strideSeconds),
                    value: value))
            }
        }
        if !chart.isEmpty {
            run.sensorSeries = chart.sorted { $0.at < $1.at }
        }
        // The Personal API exposes sampled latitude, longitude and altitude
        // with a documented sample period. Missing coordinate cells are left
        // out rather than interpolated; long gaps fail later quality checks.
        if let lats = raw["positionLat"] as? [Any],
           let longs = raw["positionLong"] as? [Any],
           !lats.isEmpty && !longs.isEmpty {
            let count = min(lats.count, longs.count)
            let heights = raw["altitude"] as? [Any] ?? []
            let stride = max(1, Int(ceil(Double(count) / 650)))
            var route: [HCRunRoutePoint] = []
            for index in Swift.stride(from: 0, to: count, by: stride) {
                guard let lat = number(lats[index]),
                      let lon = number(longs[index]),
                      (-90...90).contains(lat),
                      (-180...180).contains(lon),
                      lat.isFinite, lon.isFinite else { continue }
                let height: Double? = index < heights.count ?
                    number(heights[index]) : nil
                route.append(HCRunRoutePoint(
                    latitude: lat, longitude: lon,
                    altitudeMeters: height,
                    recordedAt: started.addingTimeInterval(
                        Double(index) * strideSeconds)))
            }
            if route.count >= 8 { run.routePoints = route }
        }
        // Heart-rate time series are retained separately so the running
        // analytics engine can inspect same-session HR/speed trends.
        if let rates = raw["heartrate"] as? [Any], !rates.isEmpty {
            let step = max(1, Int(ceil(Double(rates.count) / 450)))
            var recorded: [HCRunHeartPoint] = []
            for index in Swift.stride(from: 0, to: rates.count, by: step) {
                guard let bpm = number(rates[index]),
                      (35...240).contains(bpm) else { continue }
                recorded.append(HCRunHeartPoint(
                    at: started.addingTimeInterval(
                        Double(index) * strideSeconds), bpm: bpm))
            }
            if !recorded.isEmpty { run.heartRateTrace = recorded }
        }
    }

    /// Reject cross-domain 'next' links so a bearer token can never be sent
    /// to an untrusted host.
    private static func getJSON(_ url: URL, token: String) async throws -> [String: Any] {
        guard url.scheme == "https", url.host == "www.tredict.com",
              url.path.hasPrefix("/api/oauth/v2/") else {
            throw NSError(domain: "imun", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "Untrusted Tredict API URL."])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 35
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "imun", code: 101,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected Tredict response."])
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw NSError(domain: "imun", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey:
                    "Tredict token not active or missing read permission. Open Tredict and confirm activityRead / bodyvaluesRead."])
        }
        if http.statusCode == 429 {
            throw NSError(domain: "imun", code: 429,
                userInfo: [NSLocalizedDescriptionKey: "Tredict rate limit reached. Please retry later."])
        }
        guard (200...299).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "imun", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Tredict returned an invalid activity response."])
        }
        return object
    }

    private static func endpoint(_ name: String, query: [URLQueryItem] = []) -> URL {
        var c = URLComponents(string: "https://www.tredict.com/api/oauth/v2/\(name)")!
        c.queryItems = query
        return c.url!
    }

    private static func optionalJSON(_ name: String, token: String,
                                     query: [URLQueryItem] = []) async -> [String: Any]? {
        try? await getJSON(endpoint(name, query: query), token: token)
    }

    private static func fetchAll(token: String) async throws
        -> (snapshot: HCTredictSnapshot, raw: [String: Any]) {
        var rows: [[String: Any]] = []
        var rawPages: [[String: Any]] = []
        var next: URL? = endpoint("activityList", query: [
            URLQueryItem(name: "pageSize", value: "500"),
            URLQueryItem(name: "extendedSummary", value: "1")
        ])
        var seenURLs = Set<String>()

        // Max 30 pages / 15,000 entries per explicit import, with no silent
        // frequent polling. Users can manually refresh later.
        for _ in 0..<30 {
            guard let url = next, !seenURLs.contains(url.absoluteString) else { break }
            seenURLs.insert(url.absoluteString)
            let page = try await getJSON(url, token: token)
            rawPages.append(page)
            let embedded = page["_embedded"] as? [String: Any]
            let current = embedded?["activityList"] as? [[String: Any]] ?? []
            rows.append(contentsOf: current)
            let links = page["_links"] as? [String: Any]
            let nextLink = links?["next"] as? [String: Any]
            next = (nextLink?["href"] as? String).flatMap(URL.init(string:))
            if current.isEmpty { break }
        }

        let hrv = await optionalJSON("hrv", token: token, query: [
            URLQueryItem(name: "endDate", value: "2010-01-01T00:00:00.000Z")
        ])
        let sleep = await optionalJSON("sleep", token: token, query: [
            URLQueryItem(name: "endDate", value: "2010-01-01T00:00:00.000Z")
        ])
        let body = await optionalJSON("bodyvalues", token: token)
        let capacity = await optionalJSON("capacity", token: token)
        let equipment = await optionalJSON("equipmentList", token: token)

        // Read-only detailed downloads are bounded to six recent runs per
        // user-triggered refresh. A missing detailed response must never
        // prevent the rest of the history from importing.
        var details: [String: [String: Any]] = [:]
        let newestRuns = rows.filter {
            ($0["sportType"] as? String)?.lowercased() == "running"
        }.sorted {
            ($0["date"] as? String ?? "") >
                ($1["date"] as? String ?? "")
        }
        for row in newestRuns.prefix(6) {
            guard let id = row["id"] as? String,
                  let encoded = id.addingPercentEncoding(
                    withAllowedCharacters: .urlPathAllowed) else { continue }
            details[id] = await optionalJSON("activity/" + encoded,
                token: token, query: [
                    URLQueryItem(name: "extraValues", value: "1"),
                    URLQueryItem(name: "allSeries", value: "1"),
                    URLQueryItem(name: "withLaps", value: "1")
                ])
        }

        var activities: [HCTrainingActivity] = []
        var runs: [HCProgressRun] = []
        var used = Set<String>()
        for row in rows {
            guard let sourceID = row["id"] as? String,
                  !used.contains(sourceID),
                  let timestamp = row["date"] as? String else { continue }
            used.insert(sourceID)
            let extended = row["extendedSummary"] as? [String: Any] ?? [:]
            // Extended summaries contain strength, running and sensor
            // metrics absent from shorter list responses. Favor explicitly
            // recorded values when both representations are present.
            let summary = extended.merging(row["summary"] as? [String: Any] ?? [:]) {
                _, recorded in recorded
            }
            let sport = (row["sportType"] as? String ?? "other").lowercased()
            let subSport = (row["subSportType"] as? String ?? "").lowercased()
            let title = row["title"] as? String ?? sport.capitalized
            let day = dateString(timestamp)
            let isGarmin = row["isFromGarminApi"] as? Bool ?? false
            let originalSource = row["attribution"] as? String
            let source = originalSource ?? (isGarmin ? "Garmin via Tredict" : "Tredict")
            let kind = sport == "running" ? "run" :
                (subSport == "strength_training" ? "lift" : sport)
            let distance = number(summary["distance"])
            let duration = number(summary["duration"])
            let avgHR = number(summary["heartrate"])
            var a = HCTrainingActivity(
                id: "tredict:\(sourceID)",
                date: day, title: title, kind: kind,
                source: source, distanceMeters: distance,
                durationSeconds: duration,
                averageBPM: avgHR,
                maxBPM: number(summary["heartrateMax"]),
                calories: number(summary["calories"]),
                perceivedEffort: number(row["perceivedEffort"]))
            a.totalDurationSeconds = number(summary["durationTotal"])
            a.paceSecondsPerKm = number(summary["pace"])
            a.enjoyment = number(row["enjoyment"])
            a.attribution = originalSource
            a.externalID = sourceID
            a.powerWatts = number(summary["power"])
            a.cadenceSPM = number(summary["cadence"])
            a.ascentMeters = number((summary["altitude"] as? [String: Any])?["ascent"])
            a.strengthSetCount = number(summary["exerciseSetCount"]).map(Int.init)
            a.strengthRepetitions = number(summary["repetitions"]).map(Int.init)
            a.tonnageKilograms = number(summary["volume"])
            a.maxSetWeightKilograms = number(summary["weightMax"])
            a.activeSetSeconds = number(summary["durationSets"])
            a.restSeconds = number(summary["durationRest"])
            a.runningEffectiveness = number(summary["runningEffectiveness"])
            a.vo2Max = number(summary["vo2max"])
            activities.append(a)
            if sport == "running" {
                var r = HCProgressRun(id: "tredict:\(sourceID)", date: day,
                                      title: title, source: source,
                                      distanceMeters: distance,
                                      durationSeconds: duration,
                                      averageBPM: avgHR, splits: [])
                r.maxBPM = number(summary["heartrateMax"])
                r.activeCalories = number(summary["calories"])
                r.averagePowerWatts = number(summary["power"])
                r.averageCadenceSPM = number(summary["cadence"])
                r.elevationGainMeters = number((summary["altitude"] as? [String: Any])?["ascent"])
                if let detail = details[sourceID] {
                    enrichRun(&r, detail: detail)
                }
                runs.append(r)
            }
        }

        let hrvTable = hrv?["hrv"] as? [String: [Any]] ?? [:]
        let sleepTable = sleep?["sleep"] as? [String: [Any]] ?? [:]
        let dates = Set(hrvTable.keys).union(sleepTable.keys)
        let recovery = dates.compactMap { key -> HCRecoveryDatum? in
            guard key.count == 8 else { return nil }
            let day = "\(key.prefix(4))-\(key.dropFirst(4).prefix(2))-\(key.suffix(2))"
            let h = hrvTable[key] ?? []
            let t = sleepTable[key] ?? []
            return HCRecoveryDatum(date: day,
                                  sleepSeconds: t.first.flatMap(number),
                                  hrvMS: h.first.flatMap(number),
                                  hrvBaselineMS: h.count > 1 ? number(h[1]) : nil,
                                  dailyLowHR: nil,
                                  source: "Tredict Personal API")
        }.sorted { $0.date > $1.date }

        var sourceTypes = ["activities"]
        if hrv != nil { sourceTypes.append("HRV") }
        if sleep != nil { sourceTypes.append("sleep") }
        if body != nil { sourceTypes.append("body measurements") }
        if capacity != nil { sourceTypes.append("fitness capacities") }
        if equipment != nil { sourceTypes.append("equipment") }
        var result = HCTredictSnapshot()
        result.activities = activities.sorted { $0.date > $1.date }
        result.runs = runs.sorted { $0.date > $1.date }
        result.recovery = recovery
        result.lastSync = Date()
        result.rawActivityCount = used.count
        result.dataTypes = sourceTypes
        let raw: [String: Any] = [
            "retrievedAt": ISO8601DateFormatter().string(from: Date()),
            "origin": "Tredict Personal API (read-only)",
            "activityListPages": rawPages,
            "hrv": hrv ?? [:],
            "sleep": sleep ?? [:],
            "bodyvalues": body ?? [:],
            "capacity": capacity ?? [:],
            "equipment": equipment ?? [:]
        ]
        return (result, raw)
    }
}
