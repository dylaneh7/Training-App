# imun Coach — Chat-first home and seven-day plan

## Overview
The Coach bottom tab is now the primary conversational workspace. The separate full-screen Ask Coach and small embedded chat were combined into one visible, polished conversation with a seven-day planned-workout outlook directly beneath it.

## User experience
- **Chat first:** Coach title, message history, suggested questions, multiline composer, send button and optional recovery-context toggle.
- **Clean appearance:** no developer/server configuration banners or technical status chips in the normal conversation. Errors appear only when a request actually fails, so the user can retry.
- **Keyboard:** scroll-to-dismiss interaction and a keyboard accessory **Done** button, plus a visible **Done typing** action while the composer is focused; sending also closes the keyboard.
- **Conversation continuity:** up to the most recent 24 chat turns are stored locally on the device. The pencil icon starts a new conversation and clears the local copy.
- **AI handling:** coaching requests still use the signed-in user's authenticated backend and limited, user-initiated context. The recovery toggle is opt-in; no continuous health-data upload. A request failure leaves the question in the composer so it can be retried. A functioning model still depends on correct Supabase provider credentials and a real signed-in test.
- **Next 7 days:** seven dated rows (today + six), with every planned workout for each date, labeled by activity and completed state. An unscheduled date is clearly labeled as such. Tapping a planned session opens the existing move-date flow; no implicit schedule edits. The same seven-day schedule is included in the coach's question-specific AI context.
- **Settings:** the gear in the top right still opens all existing settings. Native Watch code, source-of-truth schedule sync and other application tabs remain unchanged.

## Device acceptance
1. Pull `main` in the GitHub-connected Xcode project, run iPhone HealthCoach once.
2. Coach is immediately chat-first, not a hero, dashboard, then separate chat entry.
3. Tap a suggested question, type, dismiss keyboard using Done and by scrolling; send, navigate away/back, verify chat history remains.
4. Under the chat, scroll through exactly seven local calendar dates; verify the workout titles against the connected Command Center planner. Move a session through its existing sheet and verify updated planner after sync.
5. New conversation button clears on-device chat. No raw recovery content is sent until user opts in and asks.
6. No “server configured”/“setup needed” statuses appear unless an actual chat failure requires an explanation.

This is an iPhone UI update; no Watch native code changed. Tests compile both original Xcode targets; successful compilation does not prove live AI API credentials or physical keyboard behavior without device checks.
