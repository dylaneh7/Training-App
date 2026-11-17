# Build 36 — IsAIah Chat QA

## Design contract
- Chat uses a full-height sheet, not a nested scrolling Coach dashboard.
- Approved Option C IsAIah artwork is vector-traced from the selected image, not re-created with a system font. Cream/crimson/graphite mark remains constant across themes.
- Main app and chat surfaces use the active IMUN theme. The composer uses an intentionally blue action button when sendable.
- Top header fills the width with the full IsAIah logo.
- Thread scrolls independently of the composer; send controls remain visible above the software keyboard.
- First open should focus the input automatically. After send, existing chat persistence, feedback and error recovery still operate.
- Preserve approved action review and confirmation semantics.

## Health data contract
- Device collects already-authorized HealthKit data; no new account permissions or screen capture.
- All **loaded** Health metrics for all source providers are enumerated from `HCAppleHealthReader.metrics` on send, regardless of viewport or scrolling.
- Each measurement retains metric name, value, source, category, units, and date.
- Requested/selected metrics include their recent history if available; all other current metric cards remain in the snapshot.
- Synced non-HealthKit recovery records are also included when authorized.
- Health data remains behind the persisted, visible `Include all loaded Health readings` toggle, never sent merely by opening the chat.
- Requests from other tabs still inherit the relevant tab and plan context.
- Backend input ceiling is 24,000 characters, with authenticated Supabase Edge Function v9. Larger data sets are bounded rather than silently claiming historical completeness.

## QA checkpoints
- [ ] Xcode iOS compile on latest branch
- [ ] Xcode watchOS compile on latest branch
- [ ] Verify logo matches selected image in dark and light themes
- [ ] Test first-open focus, keyboard covering, send button, multiline composition
- [ ] Test one new message, subsequent messages, scroll to latest, waiting indicator, failed request, retry, close and reopen
- [ ] Test action confirmation after chat redesign (edit workout, move workout, settings)
- [ ] Health sharing OFF: IsAIah should know Health screen category but receive no measured readings
- [ ] Health sharing ON: WHOOP, Apple Watch and other loaded metric cards included even below the fold
- [ ] Verify HRV methods and source provenance not merged
- [ ] Verify when HealthKit permissions are absent, assistant says no data instead of inventing
- [ ] Verify iPhone/Watch installs on top of Build 35 without wiping user data

## Scope
Build 36 changes only IsAIah presentation/branding and on-demand context sharing, plus a backward-compatible backend context-size change. It does not revise strength/watch workout recording or request new HealthKit authorizations.
