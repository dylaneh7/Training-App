using Toybox.Application.Storage;
using Toybox.Time;
using Toybox.Time.Gregorian;

module WorkoutStore {
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

    function sessionName(day) {
        if (day == "Mon") { return "PUSH"; }
        if (day == "Tue") { return "PULL"; }
        if (day == "Wed") { return "UPPER SUPPORT"; }
        if (day == "Thu") { return "LEGS"; }
        return "RECOVERY / RUN";
    }

    function exercises(day) {
        if (day == "Mon") {
            return [
                exercise("Flat Barbell Bench", 4, 8, 2),
                exercise("Incline DB Press", 3, 10, 2),
                exercise("Weighted Dip", 3, 10, 1),
                exercise("Seated DB Shoulder Press", 3, 10, 2),
                exercise("Chest-Supported Lateral Raise", 3, 15, 1),
                exercise("Standing Lateral Raise", 3, 15, 1),
                exercise("Cable Rear-Delt Fly", 3, 15, 1),
                exercise("Close-Grip Bench", 3, 10, 2),
                exercise("Overhead Cable Triceps", 3, 12, 1),
                exercise("Rope Pressdown", 3, 12, 1)
            ];
        }
        if (day == "Tue") {
            return [
                exercise("Weighted Pull-Up / Pulldown", 4, 8, 2),
                exercise("Chest-Supported T-Bar Row", 4, 10, 2),
                exercise("Single-Arm Cable Lat Row", 3, 10, 2),
                exercise("Wide High Row", 3, 12, 2),
                exercise("Straight-Arm Pulldown", 3, 12, 1),
                exercise("Dumbbell Shrug", 3, 12, 1),
                exercise("Cable Y-Raise", 3, 15, 1),
                exercise("Reverse Pec Deck", 3, 15, 1),
                exercise("Face Pull", 3, 15, 1),
                exercise("Incline DB Curl", 3, 10, 1),
                exercise("Preacher Curl", 3, 10, 1),
                exercise("Hammer Curl", 3, 12, 1),
                exercise("Reverse EZ-Bar Curl", 3, 12, 1),
                exercise("Farmer Carry", 3, 1, 2)
            ];
        }
        if (day == "Wed") {
            return [
                exercise("Paused Bench Press", 3, 8, 2),
                exercise("Low-to-High Cable Fly", 3, 12, 1),
                exercise("Neutral-Grip Pulldown", 3, 10, 2),
                exercise("Chest-Supported Machine Row", 3, 10, 2),
                exercise("Cable Lateral Raise", 3, 15, 1),
                exercise("Cable Rear-Delt Fly", 3, 15, 1),
                exercise("Rope Pressdown", 3, 12, 1),
                exercise("Cable Curl", 3, 12, 1),
                exercise("Cable External Rotation", 2, 15, 3)
            ];
        }
        if (day == "Thu") {
            return [
                exercise("Back Squat / Hack Squat", 4, 8, 2),
                exercise("Romanian Deadlift", 4, 8, 2),
                exercise("Leg Press", 3, 10, 2),
                exercise("Bulgarian Split Squat", 3, 10, 2),
                exercise("Leg Extension", 3, 12, 1),
                exercise("Seated Leg Curl", 3, 12, 1),
                exercise("Hip Thrust", 3, 10, 2),
                exercise("Standing Calf Raise", 4, 12, 1),
                exercise("Seated Soleus Raise", 3, 15, 1),
                exercise("Cable Crunch / Ab Wheel", 3, 12, 1)
            ];
        }
        return [];
    }

    function exercise(name, sets, reps, rir) {
        return {"name" => name, "sets" => sets, "reps" => reps, "rir" => rir};
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
