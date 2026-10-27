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

        // Keep the header narrow enough for the round top of the 970 display.
        dc.setColor(0xBEBEBE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 56, Graphics.FONT_SMALL, "HEALTH COACH", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 96, Graphics.FONT_LARGE, whole(_data[:readiness]), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 143, Graphics.FONT_SMALL, _data[:status], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x3B3B3B, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(82, 178, width - 82, 178);

        drawMetric(dc, 198, "BODY BATTERY", whole(_data[:bodyBattery]), 0x55D6BE);
        drawMetric(dc, 237, "STRESS", whole(_data[:stress]), 0xFFB347);
        drawMetric(dc, 276, "RECOVERY", wholeWithSuffix(_data[:recovery], " h"), 0x7AA7FF);
        drawMetric(dc, 315, "RESPIRATION", wholeWithSuffix(_data[:respiration], " br/m"), 0xC99CFF);

        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 357, Graphics.FONT_XTINY, shortAdviceForStatus(_data[:status]), Graphics.TEXT_JUSTIFY_CENTER);

        var footer = "Steps " + whole(_data[:steps]) + "   Watch " + batteryString(_data[:watchBattery]);
        dc.setColor(0x777777, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 390, Graphics.FONT_XTINY, footer, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawMetric(dc, y, label, value, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(92, y + 8, 4);

        dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(108, y, Graphics.FONT_TINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(350, y - 1, Graphics.FONT_SMALL, value, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    function whole(value) {
        if (value == null) { return "--"; }
        return value.format("%.0f");
    }

    function wholeWithSuffix(value, suffix) {
        if (value == null) { return "--"; }
        return value.format("%.0f") + suffix;
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

    function shortAdviceForStatus(status) {
        if (status == "READY") { return "Push the planned session"; }
        if (status == "STEADY") { return "Train, keep effort controlled"; }
        if (status == "EASY") { return "Easy work or lower volume"; }
        return "Prioritize recovery today";
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
