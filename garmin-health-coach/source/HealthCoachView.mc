using Toybox.Graphics;
using Toybox.WatchUi;

class HealthCoachView extends WatchUi.View {
    var _data;

    function initialize() {
        View.initialize();
        _data = HealthCoachData.snapshot();
    }

    function onShow() {
        refresh();
    }

    function refresh() {
        _data = HealthCoachData.snapshot();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var center = width / 2;
        var accent = colorForStatus(_data[:status]);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 38, Graphics.FONT_MEDIUM, "HEALTH COACH", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 92, Graphics.FONT_LARGE, _data[:readiness].toString(), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 142, Graphics.FONT_MEDIUM, _data[:status], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(65, 184, width - 65, 184);

        drawMetric(dc, 205, "BODY BATTERY", valueWithSuffix(_data[:bodyBattery], ""), 0x55D6BE);
        drawMetric(dc, 248, "STRESS", valueWithSuffix(_data[:stress], ""), 0xFFB347);
        drawMetric(dc, 291, "RECOVERY", valueWithSuffix(_data[:recovery], " h"), 0x7AA7FF);
        drawMetric(dc, 334, "RESPIRATION", valueWithSuffix(_data[:respiration], " br/m"), 0xC99CFF);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 382, Graphics.FONT_XTINY, shortAdvice(_data[:advice]), Graphics.TEXT_JUSTIFY_CENTER);

        var footer = "Steps " + valueWithSuffix(_data[:steps], "") + "  •  Watch " + batteryString(_data[:watchBattery]);
        dc.setColor(0x888888, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 416, Graphics.FONT_XTINY, footer, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawMetric(dc, y, label, value, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(86, y + 9, 5);

        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(105, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(350, y - 2, Graphics.FONT_SMALL, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function valueWithSuffix(value, suffix) {
        if (value == null) { return "--"; }
        return value.toString() + suffix;
    }

    function batteryString(value) {
        if (value == null) { return "--"; }
        return value.format("%.0f") + "%";
    }

    function colorForStatus(status) {
        if (status == "READY") { return 0x2EE6A6; }
        if (status == "STEADY") { return 0x6CB6FF; }
        if (status == "EASY") { return 0xFFB347; }
        return 0xFF6868;
    }

    function shortAdvice(advice) {
        if (advice == null) { return "Open again to refresh."; }
        if (advice.length() > 52) {
            return advice.substring(0, 49) + "...";
        }
        return advice;
    }
}

class HealthCoachDelegate extends WatchUi.BehaviorDelegate {
    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.refresh();
        return true;
    }
}
