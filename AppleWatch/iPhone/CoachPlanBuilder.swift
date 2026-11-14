import Foundation

/// Maps existing Health Coach cloud state to today's watch workout.
/// All comparisons use local calendar dates, not UTC, so a workout doesn't
/// jump to tomorrow while the user is training late at night.
enum HCPlanBuilder {
    static let firstWeek = "2026-10-26"

    static func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    static func startOfDate(_ text: String) -> Date? {
        let fmt = DateFormatter()
        fmt.calendar = Calendar(identifier: .gregorian)
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: text)
    }

    static func sessionKey(for date: Date) -> String? {
        let day = Calendar.current.startOfDay(for: date)
        guard let baseline = startOfDate(firstWeek) else { return nil }
        let age = Calendar.current.dateComponents([.day], from: baseline, to: day).day ?? -1
        guard age >= 0 else { return nil }
        let week = age / 7
        let localDate = dateString(date)
        if localDate == "2026-11-14" { return "\(week)-SatUpper" }
        let weekday = Calendar.current.component(.weekday, from: date)
        let key: String?
        switch weekday {
        case 2: key = "Mon"
        case 3: key = "Tue"
        case 4: key = week == 0 || week == 1 ? nil : "Wed"
        case 5: key = week == 0 || week == 1 ? "UpperThu" : "Thu"
        case 6: key = week == 0 || week == 1 ? "LegsFri" : nil
        default: key = nil
        }
        return key.map { "\(week)-\($0)" }
    }

    static func workout(for date: Date, planner: [String: Any], history: [String: Any]) -> HCWorkout? {
        let iso = dateString(date)
        guard let key = sessionKey(for: date) else { return nil }
        let items = planner["items"] as? [[String: Any]] ?? []
        let planned = items.first {
            ($0["date"] as? String) == iso
                && ($0["category"] as? String) == "workout"
                && ($0["type"] as? String)?.lowercased() == "lift"
        }
        // Only the user-requested one-off Saturday workout exists without a
        // Command Center Lift entry. Other missing days are genuine rest days.
        if planned == nil && !key.hasSuffix("SatUpper") { return nil }
        let title = (planned?["title"] as? String)
            ?? (key.hasSuffix("SatUpper") ? "Full Upper — Return to Training" : "Today's Strength")

        let previous = previousWorkingWeights(from: history, before: date)
        return HCProgramCatalog.makeWorkout(date: iso, sessionKey: key,
                                            title: title, savedHistory: previous)
    }

    /// Read exercise identity from the saved day's selection and known slot
    /// layouts. Never use a weight from a different exercise just because its
    /// numeric set index is the same.
    static func previousWorkingWeights(from history: [String: Any], before date: Date) -> [String: Double] {
        let days = history["days"] as? [String: [String: Any]] ?? [:]
        let extras = ((history["exerciseExtras"] as? [String: Any])?["days"] as? [String: [String: Any]]) ?? [:]
        let layouts = ((history["exerciseLayout"] as? [String: Any])?["days"] as? [String: [String: Any]]) ?? [:]
        let beforeISO = dateString(date)
        var found: [String: (date: String, weight: Double)] = [:]

        for (session, data) in days {
            let components = session.split(separator: "-")
            guard components.count == 2,
                  let w = Int(components[0]),
                  let sessionDate = dateFor(week: w, day: String(components[1])),
                  sessionDate < beforeISO
            else { continue }
            let day = String(components[1])
            let templates = HCProgramCatalog.templates(for: session)
            let choices = data["choice"] as? [String: String] ?? [:]
            let logged = data["sets"] as? [String: [String: Any]] ?? [:]

            for (index, t) in templates.enumerated() {
                let chosen = choices[String(index)] ?? t.name
                let key = identity(for: chosen)
                let prefix = "\(index)-"
                let weights = logged.compactMap { name, values -> Double? in
                    guard name.hasPrefix(prefix),
                          let reps = number(values["r"]), reps > 0,
                          let weight = number(values["w"]), weight > 0
                    else { return nil }
                    return weight
                }
                if let last = weights.max(), let old = found[key] {
                    if sessionDate >= old.date { found[key] = (sessionDate, last) }
                } else if let last = weights.max() {
                    found[key] = (sessionDate, last)
                }
            }

            let custom = extras[session] ?? [:]
            let mappedDay = day == "UpperThu" ? "Wed" : day == "LegsFri" ? "Thu" : day
            let definitions = layouts[mappedDay]?["custom"] as? [[String: Any]] ?? []
            for (customID, value) in custom {
                guard let def = definitions.first(where: { ($0["id"] as? String) == customID }),
                      let name = def["name"] as? String,
                      let setData = (value as? [String: Any])?["sets"] as? [String: [String: Any]]
                else { continue }
                let weights = setData.values.compactMap { v -> Double? in
                    guard let r = number(v["r"]), r > 0,
                          let wt = number(v["w"]), wt > 0 else { return nil }
                    return wt
                }
                guard let weight = weights.max() else { continue }
                let key = identity(for: name)
                if let old = found[key], old.date > sessionDate { continue }
                found[key] = (sessionDate, weight)
            }
        }
        return Dictionary(uniqueKeysWithValues: found.map { ($0.key, $0.value.weight) })
    }

    static func identity(for movement: String) -> String {
        let value = HCProgramCatalog.normalized(movement)
        if value.contains("bench") && value.contains("barbell") && value.contains("press") {
            return "barbell bench press"
        }
        if value.contains("lat") && value.contains("pulldown") && value.contains("neutral") {
            return "neutral lat pulldown"
        }
        return value
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func dateFor(week: Int, day: String) -> String? {
        guard let baseline = startOfDate(firstWeek) else { return nil }
        let n: Int
        switch day {
        case "Mon": n = 0
        case "Tue": n = 1
        case "Wed", "RestWed": n = 2
        case "Thu", "UpperThu": n = 3
        case "Fri", "LegsFri": n = 4
        case "Sat", "SatUpper": n = 5
        case "Sun": n = 6
        default: return nil
        }
        guard let date = Calendar.current.date(byAdding: .day, value: week * 7 + n, to: baseline) else { return nil }
        return dateString(date)
    }
}
