using Toybox.Graphics;
using Toybox.WatchUi;

(:glance)
class HealthCoachGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var day = WorkoutStore.dayKey();
        var xs = WorkoutStore.exercises(day);
        var done = WorkoutStore.completedSets(day);
        var total = WorkoutStore.totalSets(day);
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(18, h / 2, 5);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(34, h / 2 - 13, Graphics.FONT_SMALL,
            WorkoutStore.sessionName(day) + "  " + done.toString() + "/" + total.toString(),
            Graphics.TEXT_JUSTIFY_LEFT);

        var sub = "No strength session today";
        if (xs.size() > 0 && done < total) {
            var i = WorkoutStore.firstIncompleteExercise(day);
            sub = shortName(xs[i]["name"], 25);
        } else if (xs.size() > 0) {
            sub = "Workout complete";
        }

        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(34, h / 2 + 11, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function shortName(value, max) {
        if (value.length() <= max) { return value; }
        return value.substring(0, max - 3) + "...";
    }
}
