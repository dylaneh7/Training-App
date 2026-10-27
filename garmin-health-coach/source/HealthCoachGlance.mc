using Toybox.Graphics;
using Toybox.WatchUi;

(:glance)
class HealthCoachGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var data = HealthCoachData.snapshot();
        var h = dc.getHeight();
        var w = dc.getWidth();
        var color = colorForStatus(data[:status]);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(18, h / 2, 5);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(34, h / 2 - 12, Graphics.FONT_SMALL,
            "Coach " + data[:readiness].toString() + "  " + data[:status],
            Graphics.TEXT_JUSTIFY_LEFT);

        var sub = "BB " + value(data[:bodyBattery]) + "  •  Stress " + value(data[:stress]);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.drawText(34, h / 2 + 11, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function value(v) {
        return v == null ? "--" : v.toString();
    }

    function colorForStatus(status) {
        if (status == "READY") { return 0x2EE6A6; }
        if (status == "STEADY") { return 0x6CB6FF; }
        if (status == "EASY") { return 0xFFB347; }
        return 0xFF6868;
    }
}
