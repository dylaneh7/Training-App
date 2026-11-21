import SwiftUI

struct IMUNRunningTrainingTools: View {
    let runs: [HCProgressRun]
    let planned: [HCPlannedSession]
    @ObservedObject private var book = IMUNRunningLogbook.shared
    @State private var goalMiles = ""
    @State private var goalRuns = ""
    @State private var shoeName = ""
    @State private var shoeStartingMiles = ""
    @State private var raceName = ""
    @State private var raceDate = Date()
    @State private var raceDistance = "5000"
    @State private var raceGoal = ""
    @State private var inputError: String? = nil

    private var activeShoes: [IMUNRunningShoe] {
        book.data.shoes.filter { !$0.retired }
    }
    private var weekPreview: [(week: Int, miles: Double, focus: String)] {
        let upcoming = book.data.races.filter {
            $0.on >= Date()
        }.sorted { $0.on < $1.on }.first?.on
        return IMUNRunAdvancedAnalytics.fourWeekPreview(
            runs, targetMiles: book.data.goalMilesPerWeek,
            raceDate: upcoming)
    }

    var body: some View {
        Form {
            Section {
                TextField("Miles per week (optional)", text: $goalMiles)
                    .keyboardType(.decimalPad)
                TextField("Runs per week (optional)", text: $goalRuns)
                    .keyboardType(.numberPad)
                Button("Save training goals") {
                    let miles = Double(goalMiles)
                    let days = Int(goalRuns)
                    guard (goalMiles.isEmpty || (miles.map {
                        (1...250).contains($0)
                    } ?? false)) &&
                          (goalRuns.isEmpty || (days.map {
                              (1...21).contains($0)
                          } ?? false)) else {
                        inputError = "Enter valid optional targets: 1–250 miles and 1–21 runs."
                        return
                    }
                    book.setGoal(miles: miles, runs: days)
                    inputError = nil
                }
                ForEach(book.goalStatus(in: runs), id: \.self) { text in
                    Text(text).font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: { Text("Weekly goals") }
            footer: {
                Text("Rolling seven-day recorded results. These are self-selected goals, not injury-risk thresholds or automatically prescribed mileage.")
            }

            Section {
                if weekPreview.isEmpty {
                    Text("Once multiple recent weeks and at least two runs in the last seven days are recorded, iMun can show a conservative four-week mileage preview.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(weekPreview.indices, id: \.self) { index in
                        let entry = weekPreview[index]
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Week \(entry.week)")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(entry.focus)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(String(format:"%.1f mi", entry.miles))
                                .font(HCDesign.metric(16))
                        }
                    }
                }
            } header: { Text("Four-week mileage preview") }
            footer: {
                Text("Illustrative progression based on recorded volume, not a prescribed plan or injury assessment. Taper preview excludes event distance. IsAIah or your coach should confirm workout intensity, progression and race goals.")
            }

            if let score = book.scheduleAdherence(planned, runs: runs) {
                Section("Calendar consistency") {
                    Text("\(score.matched) / \(score.planned) scheduled run dates matched.")
                    Text("An imported workout matches the scheduled day, not automatically its duration, route or interval targets.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(book.data.shoes) { shoe in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(shoe.name)
                                .font(.system(size: 14, weight: .semibold))
                            Text(String(format:"%.1f total tracked mi",
                                book.miles(for: shoe, in: runs)))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(shoe.retired ? "Restore" : "Retire") {
                            book.retireShoe(shoe.id, retired: !shoe.retired)
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.borderless)
                    }
                }
                TextField("New shoe name", text: $shoeName)
                TextField("Existing miles (optional)",
                          text: $shoeStartingMiles)
                    .keyboardType(.decimalPad)
                Button("Add running shoes") {
                    let starting = Double(shoeStartingMiles) ?? 0
                    guard !shoeName.trimmingCharacters(
                        in: .whitespacesAndNewlines).isEmpty &&
                        (0...10000).contains(starting) else {
                        inputError = "Enter a shoe name and valid starting mileage."
                        return
                    }
                    book.addShoe(shoeName, startingMiles: starting)
                    shoeName = ""
                    shoeStartingMiles = ""
                    inputError = nil
                }
            } header: { Text("Running shoes") }
            footer: {
                Text("Mileage accumulates only for runs you explicitly assign to a shoe. No automatic shoe detection and no universal replacement threshold.")
            }

            Section {
                ForEach(book.data.races) { race in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(race.name)
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            Button(role: .destructive) {
                                book.removeRace(race.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        Text(race.on.formatted(date: .abbreviated,
                                               time: .omitted) + " · " +
                             String(format:"%.1f km",
                                race.distanceMeters / 1000))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                TextField("Race or event name", text: $raceName)
                DatePicker("Race date", selection: $raceDate,
                           displayedComponents: .date)
                Picker("Distance", selection: $raceDistance) {
                    Text("1 mile").tag("1609.344")
                    Text("5K").tag("5000")
                    Text("10K").tag("10000")
                    Text("Half marathon").tag("21097.5")
                    Text("Marathon").tag("42195")
                    Text("70.3 run leg").tag("21097.5-tri")
                }
                TextField("Target finish time (mm:ss or h:mm:ss)",
                          text: $raceGoal)
                    .keyboardType(.numbersAndPunctuation)
                Button("Add event") {
                    guard let distance = Double(raceDistance
                        .replacingOccurrences(of: "-tri", with: "")),
                          !raceName.trimmingCharacters(
                              in: .whitespacesAndNewlines).isEmpty,
                          let finish = Self.parseDuration(raceGoal)
                          else {
                        inputError = "Enter an event name and a valid optional finish time."
                        return
                    }
                    book.addRace(name: raceName, date: raceDate,
                                 meters: distance, goalSeconds: finish)
                    raceName = ""
                    raceGoal = ""
                    inputError = nil
                }
            } header: { Text("Race calendar") }
            footer: {
                Text("Events are local planning records. Adding a race does not silently change a connected training plan or calendar.")
            }

            if let inputError {
                Section {
                    Text(inputError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            if let warning = book.lastError {
                Section {
                    Text(warning)
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HCDesign.canvas)
        .tint(HCDesign.electric)
        .navigationTitle("Running Program")
        .onAppear {
            goalMiles = book.data.goalMilesPerWeek.map {
                String(format: "%.1f", $0)
            } ?? ""
            goalRuns = book.data.goalRunsPerWeek.map(String.init) ?? ""
        }
    }

    private static func parseDuration(_ text: String) -> Double?? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return .some(nil) }
        let segments = cleaned.split(separator: ":")
        guard segments.count == 2 || segments.count == 3 else { return nil }
        let numbers = segments.compactMap { Int($0) }
        guard numbers.count == segments.count,
              numbers.allSatisfy({ $0 >= 0 }) else { return nil }
        let seconds: Int
        if numbers.count == 3 {
            guard numbers[1] < 60 && numbers[2] < 60 else { return nil }
            seconds = numbers[0] * 3600 + numbers[1] * 60 + numbers[2]
        } else {
            guard numbers[1] < 60 else { return nil }
            seconds = numbers[0] * 60 + numbers[1]
        }
        guard (60...200000).contains(seconds) else { return nil }
        return .some(Double(seconds))
    }
}

struct IMUNRunningJournalEditor: View {
    let run: HCProgressRun
    @ObservedObject private var book = IMUNRunningLogbook.shared
    @Environment(\.dismiss) private var dismiss
    @State private var note = IMUNRunningRunNote()
    @State private var hydration = ""
    @State private var temperature = ""
    @State private var hasFuel = false
    @State private var saveError = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Recorded run", value: run.date)
                LabeledContent("Source", value: run.source)
                Picker("Running shoes", selection: $note.shoeID) {
                    Text("Not assigned").tag(UUID?.none)
                    ForEach(book.data.shoes) { shoe in
                        Text(shoe.name + (shoe.retired ? " (retired)" : ""))
                            .tag(Optional(shoe.id))
                    }
                }
                Picker("Effort", selection: $note.effort) {
                    Text("Not entered").tag(Int?.none)
                    ForEach(1...10, id: \.self) { number in
                        Text("\(number) / 10").tag(Optional(number))
                    }
                }
            } header: { Text("Session") }
            footer: {
                Text("Perceived effort is your own rating, not a measured physiological score.")
            }
            Section("Your training notes") {
                TextEditor(text: $note.notes)
                    .frame(minHeight: 110)
                TextField("Fueling, gels, snacks", text: $note.fueling,
                          axis: .vertical)
                    .lineLimit(2...5)
            }
            Section("Optional conditions") {
                TextField("Hydration during run, fluid ounces",
                          text: $hydration)
                    .keyboardType(.decimalPad)
                TextField("Observed temperature, °F", text: $temperature)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Weather, terrain, humidity notes",
                          text: $note.weatherNotes, axis: .vertical)
                    .lineLimit(2...5)
                Text("Manual notes are not a weather API, body-fluid sensor, or measured sweat-loss estimate.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if saveError {
                Section {
                    Text("Check hydration (0–1000 fl oz) and temperature (-80 to 160 °F).")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            Section {
                Button("Save run journal") {
                    let ounces = Double(hydration)
                    let degrees = Double(temperature)
                    guard (hydration.isEmpty || ounces.map {
                        (0...1000).contains($0)
                    } == true),
                    (temperature.isEmpty || degrees.map {
                        (-80...160).contains($0)
                    } == true) else {
                        saveError = true
                        return
                    }
                    note.hydrationOunces = ounces
                    note.temperatureF = degrees
                    book.setNote(note, for: run.id)
                    dismiss()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(HCDesign.canvas)
        .tint(HCDesign.electric)
        .navigationTitle("Run Journal")
        .onAppear {
            note = book.note(for: run.id)
            hydration = note.hydrationOunces.map {
                String(format: "%.1f", $0)
            } ?? ""
            temperature = note.temperatureF.map {
                String(format: "%.1f", $0)
            } ?? ""
        }
    }
}
