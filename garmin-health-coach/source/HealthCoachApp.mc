using Toybox.Application;
using Toybox.WatchUi;

class HealthCoachApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new WorkoutView();
        return [view, new WorkoutDelegate(view)];
    }

    function getGlanceView() {
        return [new HealthCoachGlanceView()];
    }
}
