using Toybox.Graphics;
using Toybox.WatchUi;

class WorkoutView extends WatchUi.View {
    var _day;
    var _exercises;
    var _screen = 0; // 0 home, 1 exercise, 2 edit
    var _exerciseIndex = 0;
    var _setIndex = 0;
    var _selected = 0; // weight, reps, rir, complete
    var _editingField = 0;
    var _editValue = 0;
    var _originalValue = 0;

    function initialize() {
        View.initialize();
        reload();
    }

    function reload() {
        _day = WorkoutStore.dayKey();
        _exercises = WorkoutStore.exercises(_day);
        if (_exercises.size() > 0) {
            _exerciseIndex = WorkoutStore.firstIncompleteExercise(_day);
            _setIndex = WorkoutStore.firstIncompleteSet(_day, _exerciseIndex);
        }
    }

    function onShow() {
        reload();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        if (_screen == 0) {
            drawHome(dc);
        } else if (_screen == 1) {
            drawExercise(dc);
        } else {
            drawEditor(dc);
        }
    }

    function drawHome(dc) {
        var center = dc.getWidth() / 2;
        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 58, Graphics.FONT_SMALL, "HYBRID COACH", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x8A8A8A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 105, Graphics.FONT_XTINY, "TODAY", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 135, Graphics.FONT_LARGE, WorkoutStore.sessionName(_day), Graphics.TEXT_JUSTIFY_CENTER);

        if (_exercises.size() == 0) {
            dc.setColor(0x9A9A9A, Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, 210, Graphics.FONT_SMALL, "No strength session", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, 248, Graphics.FONT_XTINY, "Run / recover as planned", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var done = WorkoutStore.completedSets(_day);
        var total = WorkoutStore.totalSets(_day);
        dc.setColor(0x9ED7B4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 205, Graphics.FONT_MEDIUM, done.toString() + " / " + total + " SETS", Graphics.TEXT_JUSTIFY_CENTER);

        var next = _exercises[_exerciseIndex]["name"];
        dc.setColor(0x8A8A8A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 265, Graphics.FONT_XTINY, "NEXT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 294, Graphics.FONT_SMALL, shortName(next, 27), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 370, Graphics.FONT_TINY, "START  •  OPEN WORKOUT", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawExercise(dc) {
        var center = dc.getWidth() / 2;
        var ex = _exercises[_exerciseIndex];
        var setCount = ex["sets"];
        var done = WorkoutStore.isDone(_day, _exerciseIndex, _setIndex);

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 42, Graphics.FONT_XTINY,
            (_exerciseIndex + 1).toString() + " / " + _exercises.size().toString(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 76, Graphics.FONT_SMALL, shortName(ex["name"], 28), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(done ? 0x9ED7B4 : 0xB0B0B0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 118, Graphics.FONT_TINY,
            "SET " + (_setIndex + 1).toString() + " OF " + setCount.toString() + (done ? "  ✓" : ""),
            Graphics.TEXT_JUSTIFY_CENTER);

        var weight = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "weight", 0);
        var reps = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "reps", ex["reps"]);
        var rir = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "rir", ex["rir"]);

        drawField(dc, 170, 0, "WEIGHT", weight == 0 ? "-- lb" : weight.toString() + " lb");
        drawField(dc, 225, 1, "REPS", reps.toString());
        drawField(dc, 280, 2, "RIR", rir >= 5 ? "5+" : rir.toString());
        drawField(dc, 340, 3, done ? "UNDO SET" : "COMPLETE SET", "START");

        dc.setColor(0x707070, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 398, Graphics.FONT_XTINY, "UP/DOWN select   BACK home", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawField(dc, y, index, label, value) {
        var selected = _selected == index;
        if (selected) {
            dc.setColor(0x18314A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(74, y - 8, 306, 46);
        }
        dc.setColor(selected ? 0x8FB8FF : 0x929292, Graphics.COLOR_TRANSPARENT);
        dc.drawText(96, y, Graphics.FONT_TINY, selected ? "> " + label : label, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(354, y - 2, Graphics.FONT_SMALL, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function drawEditor(dc) {
        var center = dc.getWidth() / 2;
        var label = _editingField == 0 ? "WEIGHT" : (_editingField == 1 ? "REPS" : "RIR");
        var value = _editValue.toString();
        if (_editingField == 0) { value += " lb"; }
        if (_editingField == 2 && _editValue >= 5) { value = "5+"; }

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 72, Graphics.FONT_SMALL, "EDIT " + label, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 170, Graphics.FONT_LARGE, value, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x9A9A9A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 260, Graphics.FONT_SMALL, "UP  +", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 305, Graphics.FONT_SMALL, "DOWN  -", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x9ED7B4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 365, Graphics.FONT_TINY, "START SAVE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 398, Graphics.FONT_XTINY, "BACK CANCEL", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function nextPage() {
        if (_screen == 2) {
            changeEdit(-1);
        } else if (_screen == 1) {
            _selected += 1;
            if (_selected > 3) { _selected = 0; }
        }
        WatchUi.requestUpdate();
    }

    function previousPage() {
        if (_screen == 2) {
            changeEdit(1);
        } else if (_screen == 1) {
            _selected -= 1;
            if (_selected < 0) { _selected = 3; }
        }
        WatchUi.requestUpdate();
    }

    function select() {
        if (_screen == 0) {
            if (_exercises.size() > 0) { _screen = 1; }
            WatchUi.requestUpdate();
            return;
        }

        if (_screen == 2) {
            saveEdit();
            return;
        }

        if (_selected < 3) {
            beginEdit(_selected);
        } else {
            toggleComplete();
        }
    }

    function back() {
        if (_screen == 2) {
            _editValue = _originalValue;
            _screen = 1;
        } else if (_screen == 1) {
            _screen = 0;
            reload();
        } else {
            return false;
        }
        WatchUi.requestUpdate();
        return true;
    }

    function beginEdit(field) {
        var ex = _exercises[_exerciseIndex];
        _editingField = field;
        if (field == 0) {
            _editValue = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "weight", 0);
        } else if (field == 1) {
            _editValue = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "reps", ex["reps"]);
        } else {
            _editValue = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "rir", ex["rir"]);
        }
        _originalValue = _editValue;
        _screen = 2;
        WatchUi.requestUpdate();
    }

    function changeEdit(direction) {
        if (_editingField == 0) {
            _editValue += direction * 5;
            if (_editValue < 0) { _editValue = 0; }
            if (_editValue > 1000) { _editValue = 1000; }
        } else if (_editingField == 1) {
            _editValue += direction;
            if (_editValue < 1) { _editValue = 1; }
            if (_editValue > 50) { _editValue = 50; }
        } else {
            _editValue += direction;
            if (_editValue < 0) { _editValue = 0; }
            if (_editValue > 5) { _editValue = 5; }
        }
    }

    function saveEdit() {
        var field = _editingField == 0 ? "weight" : (_editingField == 1 ? "reps" : "rir");
        WorkoutStore.setValue(_day, _exerciseIndex, _setIndex, field, _editValue);
        _screen = 1;
        WatchUi.requestUpdate();
    }

    function toggleComplete() {
        var done = WorkoutStore.isDone(_day, _exerciseIndex, _setIndex);
        WorkoutStore.setDone(_day, _exerciseIndex, _setIndex, !done);
        if (!done) { advance(); }
        WatchUi.requestUpdate();
    }

    function advance() {
        var ex = _exercises[_exerciseIndex];
        if (_setIndex + 1 < ex["sets"]) {
            _setIndex += 1;
            return;
        }
        if (_exerciseIndex + 1 < _exercises.size()) {
            _exerciseIndex += 1;
            _setIndex = WorkoutStore.firstIncompleteSet(_day, _exerciseIndex);
            return;
        }
        _screen = 0;
        reload();
    }

    function shortName(value, max) {
        if (value.length() <= max) { return value; }
        return value.substring(0, max - 3) + "...";
    }
}

class WorkoutDelegate extends WatchUi.BehaviorDelegate {
    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() {
        _view.nextPage();
        return true;
    }

    function onPreviousPage() {
        _view.previousPage();
        return true;
    }

    function onSelect() {
        _view.select();
        return true;
    }

    function onBack() {
        return _view.back();
    }
}
