# imun v2.1 — Compact Training + Health + AI Coach

This change is bundled as a **single source update**. It keeps the original `HealthCoachNative.xcodeproj`, iPhone and Watch targets, personal signing settings, existing WatchConnectivity sync, training history, run logging and prior v2 features.

## Training layout

- One bottom **Training** tab.
- The selector starts as a compact card with chosen activity, current-day plan name and a **Change** affordance. Tap to expand Run and Weightlifting. Selecting either immediately collapses again.
- The large permanent introductory gradient header and large stacked activity tiles are removed **from Training only** to prioritize the live workout. Other destinations retain their premium design.
- Other sports still belong under this selector when their real training engines are added.

## Health tab

- Bottom tab **Health** replaces Recovery.
- Permission-based Apple Health catalog includes ~57 supported quantity types grouped into Heart & Vitals, Sleep, Activity & Energy, Running & Cycling, Mobility, Body Measurements, Metabolic & Nutrition, and Workouts, plus sleep stages and source-specific daily workout counts.
- Categories and text search expose available measurements without placing all cards above the fold. Metrics absent from HealthKit, not granted by the user or not recorded by a device show as missing rather than zero.
- Same-source 35-day trends and charts, 7-day / 28-day personal baselines when five earlier comparable days exist, informational alerts for selected HRV/resting HR/respiratory/sleep trends. HRV SDNN (Apple Health) and RMSSD (connected Tredict-style source) remain distinct.
- HealthKit reads only with permission, never silently uploads entire Health datasets to a server. Tap Grant Health access to extend permissions; Refresh reloads samples once access is granted.
- WHOOP data **written to Apple Health** is displayed under its actual publisher. WHOOP proprietary Recovery, Strain, RMSSD HRV and sleep performance require authenticated direct WHOOP OAuth access; they **cannot be inferred or obtained just from Apple Health**. This update does not falsely advertise a direct WHOOP OAuth connection.
- The data catalog currently concentrates on meaningful fitness/vitals/activity/body/nutrition measurements, not literally every one of HealthKit's hundreds of clinical records/symptom/event document types.

## Coach AI

- The actual Coach bottom tab includes a visible, interactive conversational card. Questions and recent reply context are sent only when a user taps **Send**; a separate toggle explicitly authorizes sharing a limited summary of recovery measurements.
- Connection status checks the authenticated Supabase Edge Function's readiness. **Server configured** means the server has a key, not that a model response has been tested. **AI responding** means a signed-in chat request returned a response.
- The existing full-screen Ask Coach route is retained. Both views use the current user's Supabase JWT and the server-side `imun-ai-coach` function; provider API keys never ship in Swift code.
- The function is versioned at `supabase/functions/imun-ai-coach/index.ts`, and deployed to the user's existing project. It can report when the AI API key, model access or quota needs configuration; do not claim end-to-end AI success without a signed-in production call.
- Existing workout and calendar data remain in their current sources. The AI coach does not silently edit schedules.

## Installation and verification

1. Open the existing GitHub-cloned `AppleWatch/HealthCoachNative.xcodeproj` on Mac, choose **Integrate → Pull** from `origin/main`.
2. Press **Run** for `HealthCoach` on iPhone to install navigation / Health / AI UI updates. No Watch source files changed in this release, so its installed app does not need rebuilding solely for these changes.
3. Test Training collapse/expand; switch Run and Weightlifting, and verify the workout name matches today's iPhone calendar.
4. Open Health, grant Health permissions, browse categories, inspect source names and trends. Enable WHOOP → Apple Health in WHOOP itself if desired.
5. In Coach, check the AI server status and ask a sample training question. If it reports missing API credentials, a model error or server limitation, use that specific diagnostic to complete the backend connection.
6. Real device testing is necessary for HealthKit permissions and source attribution. Simulator builds validate compilation only.
