# EITAN × IsAIah — Adaptive Training Partner (Evidence & QA)

## Product contract

EITAN is **observed body wellness**, not a pass/fail permission slip. IsAIah's
independent coaching plan selects **Challenge**, **Adapt**, or **Recover** from
multiple days of training observations plus optional user check-ins. It is a
training conversation starter, not an injury-risk, overtraining, illness, or
medical diagnosis. Recommendations never mutate a training plan without an
explicit user-approved action.

The athlete can select **Driven** (default), **Balanced**, or **Recovery-first**
coaching tone. This does not override illness/pain warnings or any privacy
control. One night of short sleep never automatically cancels training or
implies that the next night will fully compensate.

## Evidence used to guide the design

1. Walsh NP et al. *Sleep and the athlete: narrative review and 2021 expert
   consensus recommendations.* Br J Sports Med.
   https://pubmed.ncbi.nlm.nih.gov/33144349/
   Sleep duration and accumulated restriction matter, with substantial
   individual variability. Sleep information alone does not dictate training.
2. Craven J et al. *Effects of Acute Sleep Loss on Physical Performance:
   A Systematic and Meta-Analytical Review.* Sports Med (2022).
   https://doi.org/10.1007/s40279-022-01706-y
   Acute loss can impair performance; avoid interpreting one day as either
   permission for maximal effort or a universal rest order.
3. *Autoregulated resistance training for maximal strength enhancement:
   A systematic review and network meta-analysis* (2025).
   https://pubmed.ncbi.nlm.nih.gov/40791980/
   Practical, autoregulated training can use RIR/RPE and actual performance
   to adjust load/volume, rather than blindly following a fixed daily target.
4. Saw AE et al. *Monitoring the athlete training response: subjective
   self-reported measures trump commonly used objective measures.*
   Br J Sports Med (2016).
   https://pubmed.ncbi.nlm.nih.gov/26423706/
   Brief self-report about perceived fatigue, stress, recovery and soreness
   adds meaning alongside objective sensors.
5. IOC consensus on training load and illness.
   https://pmc.ncbi.nlm.nih.gov/articles/PMC5013087/
   Review longer-term load and symptoms rather than single biomarker readings.
6. Impellizzeri FM et al. *ACWR: Conceptual Issues and Fundamental Pitfalls.*
   https://pubmed.ncbi.nlm.nih.gov/32502973/
   No ACWR-based injury prediction, hard universal injury thresholds, or
   claims that a specific amount of exercise will cause or prevent injury.

## Available observed inputs

- EITAN's current on-device physiological wellness score: same-source
  overnight HRV (SDNN and RMSSD kept separate), resting or daily-low HR,
  respiratory/wrist-temperature trends, recorded sleep duration, and activity
  balance, with sufficient baseline history required before showing a number
- 7/28-day observed training days and consecutive recorded training days
- Recorded high-effort days from **actual RIR <= 1** or **recorded 7–10 RPE**
  (where available). Intensity of an unlogged workout is **unknown**.
- Last seven days of comparable sleep duration from *one consistent source*
  (never sum duplicate Apple Health and imported sessions). Repeated short
  sleep requires at least four recorded nights.
- Optional, device-local 1–5 check-in: energy, soreness, stress, motivation,
  and a pain/illness question. No check-in is assumed healthy or unhealthy.
- Coach style controls message framing, not the score or safety logic.

## Heuristic coaching behavior (not medically validated cutoffs)

| Scenario | Expected IsAIah response |
|---|---|
| One short sleep night, no other sustained concern | Challenge if warm-ups and form support it; plan recovery, don't promise catch-up sleep |
| Stable baseline, positive check-in, moderate training load | Encourage planned effort and thoughtful progression using RIR/performance |
| 5+ consecutive *recorded* training days or high observed effort | Adapt if additional evidence warrants it; review session effort |
| 3+ low-score days **combined with** load/short sleep/subjective concerns | Recover: discuss easy day, reduced volume, sleep and plan changes |
| 8+ consecutive recorded days with substantial logged training | Recovery review even when today's score looks okay |
| Pain or illness self-reported | Recommend caution and appropriate assessment; do not encourage hard pushing |
| Insufficient HRV/sleep/training history | Lower evidence confidence, no fabricated measurements or diagnoses |
| Health data / EITAN coaching switched off | Honor the independent privacy and coaching switches |

These numbers are **app heuristics**, not study-established injury, recovery,
performance, or overtraining diagnostic thresholds.

## Consent and data retention

- Check-ins are saved locally as a rolling 90-day file; workouts and wellness
  are not uploaded automatically by the coach.
- EITAN's summarized coaching context and detailed authorized Health readings
  may be sent to IsAIah's online conversation only after the athlete enables
  Health sharing in the composer and taps Send.
- Without that opt-in, IsAIah receives general training-history context and
  coaching preferences but not EITAN's health-derived factors or check-in.
- Every workout/schedule modification still requires the user's approval.
- Device-to-Watch snapshots use the existing independent EITAN transport.

## Native acceptance checklist

- [ ] iPhone, Watch, widgets, and shared Codable models compile
- [ ] Today shows Challenge/Adapt/Recover distinct from the 0–100 wellness score
- [ ] Save and reopen an athlete check-in; the plan changes appropriately
- [ ] Single short sleep night **does not** automatically trigger Recover
- [ ] Long training streak + repeated low wellness triggers review
- [ ] Pain/illness check-in triggers cautious recovery guidance
- [ ] Missing HRV or sleep retains a valid unknown/baseline state
- [ ] Same day multi-device records do not multiply days or HRV methods
- [ ] Coaching style changes tone but never overrides pain/illness warning
- [ ] With Health sharing OFF, remote IsAIah gets no Health/EITAN check-in context
- [ ] With Health sharing ON and explicit Send, IsAIah receives source-labeled
      longitudinal evidence and recommends changes requiring confirmation
- [ ] Watch shows coaching mode/cues after EITAN sync, without altering workouts
- [ ] No performance regression in Today or Health scrolling
