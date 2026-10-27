using Toybox.ActivityMonitor;
using Toybox.SensorHistory;
using Toybox.System;

module HealthCoachData {
    function latestBodyBattery() {
        if (!(SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }

        try {
            var iterator = SensorHistory.getBodyBatteryHistory({ :period => 1 });
            if (iterator != null) {
                var sample = iterator.next();
                if (sample != null && sample has :data) {
                    return sample.data;
                }
            }
        } catch (e) {
        }
        return null;
    }

    function latestStress() {
        try {
            var info = ActivityMonitor.getInfo();
            if (info != null && info has :stressScore && info.stressScore != null) {
                return info.stressScore;
            }
        } catch (e) {
        }

        if (!(SensorHistory has :getStressHistory)) {
            return null;
        }

        try {
            var iterator = SensorHistory.getStressHistory({ :period => 1 });
            if (iterator != null) {
                var sample = iterator.next();
                if (sample != null && sample has :data) {
                    return sample.data;
                }
            }
        } catch (e) {
        }
        return null;
    }

    function snapshot() {
        var info = null;
        var stats = null;

        try { info = ActivityMonitor.getInfo(); } catch (e) {}
        try { stats = System.getSystemStats(); } catch (e) {}

        var bodyBattery = latestBodyBattery();
        var stress = latestStress();
        var recovery = null;
        var respiration = null;
        var steps = null;
        var stepGoal = null;
        var watchBattery = null;

        if (info != null) {
            if (info has :timeToRecovery) { recovery = info.timeToRecovery; }
            if (info has :respirationRate) { respiration = info.respirationRate; }
            if (info has :steps) { steps = info.steps; }
            if (info has :stepGoal) { stepGoal = info.stepGoal; }
        }

        if (stats != null && stats has :battery) {
            watchBattery = stats.battery;
        }

        var readiness = readinessScore(bodyBattery, stress, recovery);

        return {
            :bodyBattery => bodyBattery,
            :stress => stress,
            :recovery => recovery,
            :respiration => respiration,
            :steps => steps,
            :stepGoal => stepGoal,
            :watchBattery => watchBattery,
            :readiness => readiness,
            :status => statusFor(readiness),
            :advice => adviceFor(readiness, recovery)
        };
    }

    function readinessScore(bodyBattery, stress, recovery) {
        var score = 65;

        if (bodyBattery != null) {
            score = bodyBattery;
        }

        if (stress != null) {
            score = ((score * 7) + ((100 - stress) * 3)) / 10;
        }

        if (recovery != null && recovery > 0) {
            var penalty = recovery / 2;
            if (penalty > 25) { penalty = 25; }
            score -= penalty;
        }

        if (score < 0) { score = 0; }
        if (score > 100) { score = 100; }
        return score;
    }

    function statusFor(score) {
        if (score >= 75) { return "READY"; }
        if (score >= 55) { return "STEADY"; }
        if (score >= 35) { return "EASY"; }
        return "RECOVER";
    }

    function adviceFor(score, recovery) {
        if (score >= 75) {
            return "Good day to push the planned session.";
        }
        if (score >= 55) {
            return "Train as planned, but keep the effort controlled.";
        }
        if (score >= 35) {
            return "Favor easy aerobic work or reduce lifting volume.";
        }
        if (recovery != null && recovery > 24) {
            return "Recovery load is high. Make today restorative.";
        }
        return "Keep the day light and prioritize recovery.";
    }
}
