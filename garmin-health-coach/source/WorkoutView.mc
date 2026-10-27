using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.WatchUi;

class WorkoutView extends WatchUi.View {
    var _day;
    var _exercises;
    var _screen = 0; // 0 home, 1 exercise, 2 edit, 3 rest
    var _exerciseIndex = 0;
    var _setIndex = 0;
    var _selected = 0; // weight, reps, rir, complete
    var _editingField = 0;
    var _editValue = 0;
    var _originalValue = 0;
    var _days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    var _restTimer;
    var _restRemaining = 0;
    var _restActive = false;

    function initialize() {
        View.initialize();
        _restTimer = new Timer.Timer();
        _day = WorkoutStore.dayKey();
        reloadDay();
    }

    function reloadDay() {
        _exercises = WorkoutStore.exercises(_day);
        _exerciseIndex = 0;
        _setIndex = 0;
        _selected = 0;
        if (_exercises.size() > 0) {
            _exerciseIndex = WorkoutStore.firstIncompleteExercise(_day);
            _setIndex = WorkoutStore.firstIncompleteSet(_day, _exerciseIndex);
        }
    }

    function onShow() {
        WatchUi.requestUpdate();
    }

    function onHide() {
        stopRestTimer();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_screen == 0) {
            drawHome(dc);
        } else if (_screen == 1) {
            drawExercise(dc);
        } else if (_screen == 2) {
            drawEditor(dc);
        } else {
            drawRest(dc);
        }
    }

    function drawHome(dc) {
        var center = dc.getWidth() / 2;

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 47, Graphics.FONT_TINY, "HYBRID COACH", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 84, Graphics.FONT_XTINY, _day + "  WORKOUT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 113, Graphics.FONT_MEDIUM, WorkoutStore.sessionName(_day), Graphics.TEXT_JUSTIFY_CENTER);

        if (_exercises.size() == 0) {
            dc.setColor(0xA0A0A0, Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, 187, Graphics.FONT_TINY, "No strength session", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(center, 222, Graphics.FONT_XTINY, "Run / recover as planned", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
            dc.drawText(center, 356, Graphics.FONT_XTINY, "UP/DOWN  CHANGE DAY", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }

        var done = WorkoutStore.completedSets(_day);
        var total = WorkoutStore.totalSets(_day);
        dc.setColor(0x9ED7B4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 166, Graphics.FONT_SMALL, done.toString() + " / " + total + " SETS", Graphics.TEXT_JUSTIFY_CENTER);

        var next = _exercises[_exerciseIndex]["name"];
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 217, Graphics.FONT_XTINY, "NEXT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 246, Graphics.FONT_TINY, shortName(next, 23), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 329, Graphics.FONT_TINY, "START  OPEN", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 364, Graphics.FONT_XTINY, "UP/DOWN  CHANGE DAY", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawExercise(dc) {
        var center = dc.getWidth() / 2;
        var ex = _exercises[_exerciseIndex];
        var setCount = ex["sets"];
        var done = WorkoutStore.isDone(_day, _exerciseIndex, _setIndex);

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 34, Graphics.FONT_XTINY,
            (_exerciseIndex + 1).toString() + " / " + _exercises.size().toString(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 62, Graphics.FONT_TINY, shortName(ex["name"], 22), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(done ? 0x9ED7B4 : 0xA0A0A0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 96, Graphics.FONT_XTINY,
            "SET " + (_setIndex + 1).toString() + " OF " + setCount.toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        var weight = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "weight", 0);
        var reps = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "reps", ex["reps"]);
        var rir = WorkoutStore.getValue(_day, _exerciseIndex, _setIndex, "rir", ex["rir"]);

        drawField(dc, 145, 0, "WEIGHT", weight == 0 ? "-- lb" : weight.toString() + " lb");
        drawField(dc, 198, 1, "REPS", reps.toString());
        drawField(dc, 251, 2, "RIR", rir >= 5 ? "5+" : rir.toString());
        drawAction(dc, 307, 3, done ? "UNDO SET" : "COMPLETE SET");

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 370, Graphics.FONT_XTINY, "UP/DOWN SELECT   BACK HOME", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawField(dc, y, index, label, value) {
        var selected = _selected == index;
        if (selected) {
            dc.setColor(0x18314A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(88, y - 6, 278, 40);
        }

        dc.setColor(selected ? 0x8FB8FF : 0x929292, Graphics.COLOR_TRANSPARENT);
        dc.drawText(105, y, Graphics.FONT_XTINY, selected ? "> " + label : label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(346, y - 2, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function drawAction(dc, y, index, label) {
        var selected = _selected == index;
        if (selected) {
            dc.setColor(0x18314A, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(88, y - 6, 278, 40);
        }
        dc.setColor(selected ? 0x8FB8FF : 0xA0A0A0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, Graphics.FONT_TINY,
            selected ? "> " + label : label,
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawEditor(dc) {
        var center = dc.getWidth() / 2;
        var label = _editingField == 0 ? "WEIGHT" : (_editingField == 1 ? "REPS" : "RIR");
        var value = _editValue.toString();
        if (_editingField == 0) { value += " lb"; }
        if (_editingField == 2 && _editValue >= 5) { value = "5+"; }

        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 55, Graphics.FONT_XTINY, "EDIT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 82, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 150, Graphics.FONT_LARGE, value, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xA0A0A0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 258, Graphics.FONT_TINY, "UP   +", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 298, Graphics.FONT_TINY, "DOWN   -", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x9ED7B4, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 349, Graphics.FONT_TINY, "START  SAVE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 381, Graphics.FONT_XTINY, "BACK  CANCEL", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawRest(dc) {
        var center = dc.getWidth() / 2;
        var ex = _exercises[_exerciseIndex];

        dc.setColor(0xFFD28A, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 58, Graphics.FONT_SMALL, "REST", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 122, Graphics.FONT_NUMBER_MILD, restText(), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 205, Graphics.FONT_XTINY, "NEXT", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 235, Graphics.FONT_TINY, shortName(ex["name"], 22), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0xA0A0A0, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 274, Graphics.FONT_XTINY,
            "SET " + (_setIndex + 1).toString() + " OF " + ex["sets"].toString(),
            Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x8FB8FF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 339, Graphics.FONT_TINY, "START  SKIP REST", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x666666, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 376, Graphics.FONT_XTINY, "AUTO-OPENS NEXT SET", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function cycleDay(direction) {
        var index = 0;
        for (var i = 0; i < _days.size(); i += 1) {
            if (_days[i].equals(_day)) { index = i; break; }
        }
        index += direction;
        if (index < 0) { index = _days.size() - 1; }
        if (index >= _days.size()) { index = 0; }
        _day = _days[index];
        reloadDay();
    }

    function nextPage() {
        if (_screen == 2) {
            changeEdit(-1);
        } else if (_screen == 1) {
            _selected += 1;
            if (_selected > 3) { _selected = 0; }
        } else if (_screen == 0) {
            cycleDay(1);
        }
        WatchUi.requestUpdate();
    }

    function previousPage() {
        if (_screen == 2) {
            changeEdit(1);
        } else if (_screen == 1) {
            _selected -= 1;
            if (_selected < 0) { _selected = 3; }
        } else if (_screen == 0) {
            cycleDay(-1);
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

        if (_screen == 3) {
            skipRest();
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
        } else if (_screen == 3) {
            skipRest();
            return true;
        } else if (_screen == 1) {
            _screen = 0;
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
        WatchUi.requestUpdate();
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

        if (!done) {
            advance();
            if (_screen == 1) {
                _screen = 3;
                startRestTimer(90);
            } else {
                stopRestTimer();
            }
        }
        WatchUi.requestUpdate();
    }

    function advance() {
        var ex = _exercises[_exerciseIndex];
        if (_setIndex + 1 < ex["sets"]) {
            _setIndex += 1;
            _selected = 0;
            return;
        }
        if (_exerciseIndex + 1 < _exercises.size()) {
            _exerciseIndex += 1;
            _setIndex = WorkoutStore.firstIncompleteSet(_day, _exerciseIndex);
            _selected = 0;
            return;
        }
        _screen = 0;
        reloadDay();
    }

    function startRestTimer(seconds) {
        stopRestTimer();
        _restRemaining = seconds;
        _restActive = true;
        _restTimer.start(method(:restTick), 1000, true);
        WatchUi.requestUpdate();
    }

    function stopRestTimer() {
        if (_restActive) {
            _restTimer.stop();
        }
        _restActive = false;
        _restRemaining = 0;
    }

    function skipRest() {
        stopRestTimer();
        _screen = 1;
        WatchUi.requestUpdate();
    }

    function restTick() {
        if (!_restActive) { return; }

        _restRemaining -= 1;
        if (_restRemaining <= 0) {
            _restTimer.stop();
            _restRemaining = 0;
            _restActive = false;
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(100, 700)]);
            }
            _screen = 1;
        }
        WatchUi.requestUpdate();
    }

    function restText() {
        var mins = (_restRemaining / 60).toNumber();
        var secs = _restRemaining % 60;
        var secText = secs < 10 ? "0" + secs.toString() : secs.toString();
        return mins.toString() + ":" + secText;
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

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_UP) {
            _view.previousPage();
            return true;
        }
        if (key == WatchUi.KEY_DOWN) {
            _view.nextPage();
            return true;
        }
        if (key == WatchUi.KEY_START || key == WatchUi.KEY_ENTER) {
            _view.select();
            return true;
        }
        if (key == WatchUi.KEY_ESC) {
            return _view.back();
        }
        return false;
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
