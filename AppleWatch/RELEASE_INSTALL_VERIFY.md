# imun Native Install Verification — 2.3 (18)

Both the native iPhone HealthCoach target and Watch HealthCoachWatch target use **CFBundleShortVersionString 2.3** and **CFBundleVersion 18** in this release. Earlier source releases left both targets at 1.0 (1), making it difficult to tell if Xcode installed the latest binary.

## Identify what is installed, not what looks different

1. On iPhone: open imun → **Coach → Settings**, scroll to the bottom. The build label must say **imun 2.3 · build 18**.
2. On Apple Watch: open imun → **Preferences**, beneath **Appearance & Controls**, check for **imun 2.3 · build 18**.
3. Watch home should show explicit **Refresh** and **Send to iPhone** buttons. On iPhone Coach → Settings → Connections shows **Refresh & send workout to Watch**.
4. If iPhone is correct but Watch is not, the Watch installation was not updated, even if both targets compiled. Choose the **HealthCoachWatch** scheme, the actual paired Watch as the run destination (not a simulator), and press Run. If an install fails, inspect the Xcode report/error rather than repeating Pull.
5. If neither version is 2.3 (18), Xcode is building a different local checkout, branch, or bundle identifier. In Xcode navigate to **Source Control → Working Copies**, inspect which repository directory is open, and check that branch is `main` at or after this release commit. With the project selected, inspect **Signing & Capabilities → Bundle Identifier**: the intended original app is `com.dylaneh7.HealthCoachNative` and Watch is `com.dylaneh7.HealthCoachNative.watchkitapp` unless personal signing overrides it.
6. Do not delete the app casually: deleting a development build can remove offline workout logs, unsent sets or run history. Capture the installed version and Xcode install error first.
7. Once both versions are confirmed: keep iPhone imun open, on Watch press **Refresh**, then record a test set and press **Send to iPhone**. Observe whether data is acknowledged or queued.

## Build / signing notes

- `AppleWatch/HealthCoachNative.xcodeproj` is the source project. `AppleWatch/project.yml` is the alternate XcodeGen source; both include the new 2.3 (18) version.
- Pulling GitHub source alone does not install a build. Xcode compile success alone does not prove that a binary was installed on a physical device.
- Preserve personal code-signing changes if Source Control warns of a conflict in `project.pbxproj`. Do not discard them blindly.
