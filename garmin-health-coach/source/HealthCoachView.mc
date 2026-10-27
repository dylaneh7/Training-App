using Toybox.Graphics;
using Toybox.WatchUi;

class HealthCoachView extends WatchUi.View {
    var _data;
    var _page = 0;

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

    function nextPage() {
        _page = (_page + 1) % 2;
        WatchUi.requestUpdate();
    }

    function previousPage() {
        _page = (_page + 1) % 2;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (_page == 0) {
            drawSummary(dc);
        } else {
            drawDetails(dc);
        }
    }

    function drawSummary(dc) {
        var width = dc.getWidth();
        var center = width / 2;
        var accent = colorForStatus(_data[:status]);

        dc.setColor(0xAFAFAF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 48, Graphics.FONT_TINY, "HEALTH COACH", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 84, Graphics.FONT_LARGE, whole(_data[:readiness]), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(center, 132, Graphics.FONT_SMALL, _data[:status], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(96, 170, width - 96, 170);

        drawRow(dc, 194, "BODY BATTERY", whole(_data[:bodyBattery]), 0x55D6BE);
        drawRow(dc, 239, "STRESS", whole(_data[:stress]), 0xFFB347);
        drawRow(dc, 284, "RECOVERY", wholeWithSuffix(_data[:recovery], " h"), 0x7AA7FF);

        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 338, Graphics.FONT_XTINY, shortAdviceForStatus(_data[:status]), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x707070, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 382, Graphics.FONT_XTINY, "DOWN  DETAILS", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawDetails(dc) {
        var width = dc.getWidth();
        var center = width / 2;

        dc.setColor(0xAFAFAF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 54, Graphics.FONT_TINY, "TODAY DETAILS", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x333333, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(96, 92, width - 96, 92);

        drawRow(dc, 126, "RESPIRATION", wholeWithSuffix(_data[:respiration], " br/m"), 0xC99CFF);
        drawRow(dc, 181, "STEPS", whole(_data[:steps]), 0x54C7EC);
        drawRow(dc, 236, "WATCH BATTERY", batteryString(_data[:watchBattery]), 0x68D391);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 305, Graphics.FONT_SMALL, _data[:status], Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(colorForStatus(_data[:status]), Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 342, Graphics.FONT_XTINY, shortAdviceForStatus(_data[:status]), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x707070, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, 390, Graphics.FONT_XTINY, "UP  SUMMARY", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawRow(dc, y, label, value, color) {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(100, y + 8, 4);

        dc.setColor(0xA8A8A8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(116, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(338, y - 2, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_RIGHT);
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

    function onNextPage() {
        _view.nextPage();
        return true;
    }

    function onPreviousPage() {
        _view.previousPage();
        return true;
    }
}
