using Toybox.ActivityMonitor;
using Toybox.SensorHistory;
using Toybox.System;

module HealthCoachData {
    function latestBodyBattery() {
        try {
            var iterator = SensorHistory.getBodyBatteryHistory({ :period => 1 });
            if (iterator != null) {
                var sample = iterator.next();
                if (sample != null) {
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
            if (info.stressScore != null) {
                return info.stressScore;
            }
        } catch (e) {
        }

        try {
            var iterator = SensorHistory.getStressHistory({ :period => 1 });
            if (iterator != null) {
                var sample = iterator.next();
                if (sample != null) {
                    return sample.data;
                }
            }
        } catch (e) {
        }
        return null;
    }

    function snapshot() {
        var info = ActivityMonitor.getInfo();
        var stats = System.getSystemStats();
        var bodyBattery = latestBodyBattery();
        var stress = latestStress();
        var recovery = null;
        var respiration = null;
        var steps = null;
        var stepGoal = null;

        try { recovery = info.timeToRecovery; } catch (e) {}
        try { respiration = info.respirationRate; } catch (e) {}
        try { steps = info.steps; } catch (e) {}
        try { stepGoal = info.stepGoal; } catch (e) {}

        var readiness = readinessScore(bodyBattery, stress, recovery);

        return {
            :bodyBattery => bodyBattery,
            :stress => stress,
            :recovery => recovery,
            :respiration => respiration,
            :steps => steps,
            :stepGoal => stepGoal,
            :watchBattery => stats.battery,
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
