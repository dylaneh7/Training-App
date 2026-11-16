# imun Native Install Verification — 2.3 (20)

Both the native iPhone HealthCoach target and Watch HealthCoachWatch target use **CFBundleShortVersionString 2.3** and **CFBundleVersion 20** in this release. Earlier source releases left both targets at 1.0 (1), making it difficult to tell if Xcode installed the latest binary.

## Identify what is installed, not what looks different

1. On iPhone: open imun → **Coach → Settings**, scroll to the bottom. The build label must say **imun 2.3 · build 20**.
2. On Apple Watch: open imun → **Preferences**, beneath **Appearance & Controls**, check for **imun 2.3 · build 20**.
3. Watch home should show explicit **Refresh** and **Send to iPhone** buttons. On iPhone Coach → Settings → Connections shows **Refresh & send workout to Watch** and **Check Watch connection**.
4. If iPhone says the Watch app isn't recognized, tap **Check Watch connection** and record `Paired`, `iMun Watch installed`, and `Live reachable`. A "No" under `iMun Watch installed` is a companion-install detection problem, not a schedule-download failure. In the iPhone Watch app → My Watch, confirm iMun is in Installed on Apple Watch; if not, install it, or run the Watch scheme to the physical paired Watch. Don't delete any apps to troubleshoot.
5. `Live reachable: No` doesn't itself mean the app is missing; live messaging requires both counterparts running/reachable. After connectivity is recognized, reopen both apps and try Refresh & send.

6. If iPhone is correct but Watch is not, the Watch installation was not updated, even if both targets compiled. Choose the **HealthCoachWatch** scheme, the actual paired Watch as the run destination (not a simulator), and press Run. If an install fails, inspect the Xcode report/error rather than repeating Pull.
7. If neither version is 2.3 (20), Xcode is building a different local checkout, branch, or bundle identifier. In Xcode navigate to **Source Control → Working Copies**, inspect which repository directory is open, and check that branch is `main` at or after this release commit. With the project selected, inspect **Signing & Capabilities → Bundle Identifier**: the intended original app is `com.dylaneh7.HealthCoachNative` and Watch is `com.dylaneh7.HealthCoachNative.watchkitapp` unless personal signing overrides it.
8. Do not delete the app casually: deleting a development build can remove offline workout logs, unsent sets or run history. Capture the installed version and Xcode install error first.
9. Once both versions are confirmed: keep iPhone imun open, on Watch press **Refresh**, then record a test set and press **Send to iPhone**. Observe whether data is acknowledged or queued.

## Build / signing notes

- `AppleWatch/HealthCoachNative.xcodeproj` is the source project. `AppleWatch/project.yml` is the alternate XcodeGen source; both include the new 2.3 (20) version.
- Pulling GitHub source alone does not install a build. Xcode compile success alone does not prove that a binary was installed on a physical device.
- Preserve personal code-signing changes if Source Control warns of a conflict in `project.pbxproj`. Do not discard them blindly.


## Build 20 connection recovery
- Physical Watch and iPhone may both have iMun while WatchConnectivity reports an outdated installed state.
- A signed-in iPhone now **attempts the real application-context transport even when the installed flag is false**; the actual transport outcome determines success, not the flag alone.
- If the user presses Refresh & send, the app may queue a background schedule transfer and listen for a Watch receipt; this is not proof of delivery.
- When watchOS later recognizes the installation, the iPhone automatically retries today's dated schedule.
- If the OS rejects the transfer, show the transport error. Apple's WatchConnectivity registration is an OS service; an application code change cannot force the OS to register or preserve an app.
- The Watch retains offline logged sets and active clocks; deleting the Watch app can erase them.
