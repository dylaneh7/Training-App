using Toybox.Application;
using Toybox.WatchUi;

class HealthCoachApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new HealthCoachView();
        return [view, new HealthCoachDelegate(view)];
    }

    function getGlanceView() {
        return [new HealthCoachGlanceView()];
    }
}
