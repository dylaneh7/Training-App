using Toybox.Application.Storage;
using Toybox.Time;
using Toybox.Time.Gregorian;

module WorkoutStore {
    var _cloudDay = null;
    var _cloudWeek = -1;
    var _cloudExercises = null;

    function dayKey() {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var d = info.day_of_week;
        if (d == 2) { return "Mon"; }
        if (d == 3) { return "Tue"; }
        if (d == 4) { return "Wed"; }
        if (d == 5) { return "Thu"; }
        if (d == 6) { return "Fri"; }
        if (d == 7) { return "Sat"; }
        return "Sun";
    }

    function weekIndex() {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var today = Gregorian.moment({
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => 12
        });
        var base = Gregorian.moment({
            :year => 2026,
            :month => 10,
            :day => 26,
            :hour => 12
        });
        var diff = today.value() - base.value();
        if (diff <= 0) { return 0; }
        var week = (diff / (Gregorian.SECONDS_PER_DAY * 7)).toNumber();
        if (week < 0) { week = 0; }
        if (week > 11) { week = 11; }
        return week;
    }

    function isDay(day, expected) {
        return day != null && day.equals(expected);
    }

    function sessionName(day) {
        if (isDay(day, "Mon")) { return "PUSH"; }
        if (isDay(day, "Tue")) { return "PULL"; }
        if (isDay(day, "Wed")) { return "UPPER SUPPORT"; }
        if (isDay(day, "Thu")) { return "LEGS"; }
        return "RECOVERY / RUN";
    }

    function scaledSets(count) {
        var w = weekIndex();
        var factor = 1.0;
        if (w == 3 || w == 7) { factor = 0.65; }
        else if (w == 10) { factor = 0.55; }
        else if (w == 11) { factor = 0.45; }
        var scaled = (count * factor).round();
        if (scaled < 2) { scaled = 2; }
        return scaled;
    }

    function exercise(name, sets, reps, rir, stateIndex) {
        return {
            "name" => name,
            "sets" => sets,
            "reps" => reps,
            "rir" => rir,
            "stateIndex" => stateIndex
        };
    }

    function fallbackExercises(day) {
        if (isDay(day, "Mon")) {
            return [
                exercise("Flat barbell bench press", scaledSets(4), 6, 2, 0),
                exercise("Incline dumbbell press", scaledSets(3), 10, 2, 1),
                exercise("Weighted dip — chest bias", scaledSets(3), 10, 1, 2),
                exercise("Seated dumbbell shoulder press", scaledSets(3), 10, 2, 3),
                exercise("Chest-supported lateral raise", scaledSets(3), 15, 1, 4),
                exercise("Standing lateral raise", scaledSets(3), 15, 1, 5),
                exercise("Single-arm cable rear-delt fly", scaledSets(3), 15, 1, 6),
                exercise("Overhead cable triceps extension", scaledSets(3), 12, 1, 8),
                exercise("Rope pressdown", scaledSets(2), 12, 1, 9),
                exercise("Push-up plus", scaledSets(2), 15, 2, 10)
            ];
        }
        if (isDay(day, "Tue")) {
            return [
                exercise("Weighted pull-up / neutral pulldown", scaledSets(4), 8, 2, 0),
                exercise("Chest-supported T-bar row", scaledSets(4), 10, 2, 1),
                exercise("Single-arm cable lat row — elbow to hip", scaledSets(3), 12, 2, 2),
                exercise("Wide high row", scaledSets(3), 12, 2, 3),
                exercise("Straight-arm cable pulldown", scaledSets(3), 15, 1, 4),
                exercise("Dumbbell shrug", scaledSets(3), 12, 1, 5),
                exercise("Cable Y-raise", scaledSets(2), 15, 1, 6),
                exercise("Reverse pec deck", scaledSets(3), 15, 1, 7),
                exercise("Face pull with external rotation", scaledSets(2), 15, 1, 8),
                exercise("Incline dumbbell curl", scaledSets(3), 12, 1, 9),
                exercise("Preacher curl", scaledSets(3), 12, 1, 10),
                exercise("Hammer curl", scaledSets(3), 15, 1, 11),
                exercise("Reverse EZ-bar curl", scaledSets(2), 15, 1, 12),
                exercise("Farmer carry", scaledSets(2), 1, 2, 13)
            ];
        }
        if (isDay(day, "Wed")) {
            return [
                exercise("Paused bench press", scaledSets(3), 8, 2, 0),
                exercise("Low-to-high cable fly", scaledSets(2), 15, 1, 1),
                exercise("Neutral-grip pulldown", scaledSets(3), 12, 2, 2),
                exercise("Chest-supported machine row", scaledSets(3), 12, 2, 3),
                exercise("Cable lateral raise", scaledSets(2), 15, 1, 4),
                exercise("Cable rear-delt fly", scaledSets(2), 15, 1, 5),
                exercise("Rope pressdown", scaledSets(2), 12, 1, 6),
                exercise("Cable curl", scaledSets(2), 12, 1, 7),
                exercise("Cable external rotation", scaledSets(2), 15, 3, 8)
            ];
        }
        if (isDay(day, "Thu")) {
            return [
                exercise("Back squat / hack squat", scaledSets(4), 8, 2, 0),
                exercise("Romanian deadlift", scaledSets(4), 10, 2, 1),
                exercise("Leg press", scaledSets(4), 12, 2, 2),
                exercise("Bulgarian split squat", scaledSets(3), 10, 2, 3),
                exercise("Leg extension", scaledSets(3), 15, 1, 4),
                exercise("Seated leg curl", scaledSets(4), 15, 1, 5),
                exercise("Hip thrust", scaledSets(3), 12, 2, 6),
                exercise("Standing calf raise", scaledSets(4), 15, 1, 7),
                exercise("Seated soleus raise", scaledSets(3), 20, 1, 8),
                exercise("Cable crunch / ab wheel", scaledSets(3), 15, 1, 9)
            ];
        }
        return [];
    }

    function exercises(day) {
        if (_cloudExercises != null && _cloudDay != null && _cloudDay.equals(day) && _cloudWeek == weekIndex()) {
            return _cloudExercises;
        }
        return fallbackExercises(day);
    }

    function fallbackByStateIndex(day, stateIndex) {
        var xs = fallbackExercises(day);
        for (var i = 0; i < xs.size(); i += 1) {
            if (xs[i]["stateIndex"] == stateIndex) { return xs[i]; }
        }
        return null;
    }

    function numberValue(value, fallback, allowFloat) {
        if (value == null) { return fallback; }
        try {
            if (allowFloat) { return value.toFloat(); }
            return value.toNumber();
        } catch (e) {
            return fallback;
        }
    }

    function applyCloudSession(data) {
        if (data == null || data["ok"] != true || data["exercises"] == null) { return false; }

        var day = data["day"];
        var week = numberValue(data["weekIndex"], weekIndex(), false);
        var remote = data["exercises"];
        var converted = [];

        for (var i = 0; i < remote.size(); i += 1) {
            var item = remote[i];
            var stateIndex = numberValue(item["stateIndex"], i, false);
            var fallback = fallbackByStateIndex(day, stateIndex);
            var repsDefault = fallback == null ? 10 : fallback["reps"];
            var rirDefault = fallback == null ? 2 : fallback["rir"];
            var count = numberValue(item["setCount"], fallback == null ? 3 : fallback["sets"], false);
            var name = item["name"] == null ? (fallback == null ? "Exercise" : fallback["name"]) : item["name"];

            converted.add(exercise(name, count, repsDefault, rirDefault, stateIndex));

            var logs = item["sets"];
            if (logs != null) {
                for (var s = 0; s < logs.size(); s += 1) {
                    var log = logs[s];
                    var weightText = log["weight"];
                    var repsText = log["reps"];
                    var rirText = log["rir"];

                    if (weightText != null && weightText.toString().length() > 0) {
                        setValue(day, i, s, "weight", numberValue(weightText, 0, true));
                    }
                    if (repsText != null && repsText.toString().length() > 0) {
                        setValue(day, i, s, "reps", numberValue(repsText, repsDefault, false));
                    }
                    if (rirText != null && rirText.toString().length() > 0) {
                        setValue(day, i, s, "rir", numberValue(rirText, rirDefault, false));
                    }
                    setDone(day, i, s, log["done"] == true);
                }
            }
        }

        _cloudDay = day;
        _cloudWeek = week;
        _cloudExercises = converted;
        return true;
    }

    function clearCloud() {
        _cloudDay = null;
        _cloudWeek = -1;
        _cloudExercises = null;
    }

    function key(day, exIndex, setIndex, field) {
        return "w_" + day + "_" + exIndex.toString() + "_" + setIndex.toString() + "_" + field;
    }

    function getValue(day, exIndex, setIndex, field, fallback) {
        var v = Storage.getValue(key(day, exIndex, setIndex, field));
        return v == null ? fallback : v;
    }

    function setValue(day, exIndex, setIndex, field, value) {
        Storage.setValue(key(day, exIndex, setIndex, field), value);
    }

    function isDone(day, exIndex, setIndex) {
        return getValue(day, exIndex, setIndex, "done", false) == true;
    }

    function setDone(day, exIndex, setIndex, done) {
        setValue(day, exIndex, setIndex, "done", done);
    }

    function totalSets(day) {
        var xs = exercises(day);
        var total = 0;
        for (var i = 0; i < xs.size(); i += 1) {
            total += xs[i]["sets"];
        }
        return total;
    }

    function completedSets(day) {
        var xs = exercises(day);
        var total = 0;
        for (var i = 0; i < xs.size(); i += 1) {
            var count = xs[i]["sets"];
            for (var s = 0; s < count; s += 1) {
                if (isDone(day, i, s)) { total += 1; }
            }
        }
        return total;
    }

    function firstIncompleteExercise(day) {
        var xs = exercises(day);
        for (var i = 0; i < xs.size(); i += 1) {
            var count = xs[i]["sets"];
            for (var s = 0; s < count; s += 1) {
                if (!isDone(day, i, s)) { return i; }
            }
        }
        return 0;
    }

    function firstIncompleteSet(day, exIndex) {
        var xs = exercises(day);
        if (xs.size() == 0) { return 0; }
        var count = xs[exIndex]["sets"];
        for (var s = 0; s < count; s += 1) {
            if (!isDone(day, exIndex, s)) { return s; }
        }
        return count - 1;
    }
}
