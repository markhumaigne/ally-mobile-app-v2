# ALLY Mobile

Independent Flutter Android client for the existing HumAIn PH ALLY platform. Material 3, Provider, go_router and http, with microphone streaming and PCM playback for live chat. No Nx, new backend/database, direct Supabase SDK or upload packages.

## Current delivery

- One visible app introduction: the blue ALLY loading screen with a small translucent microphone badge, ALLY title, creator subtitle and pale spinner, followed by Home. The separate Android startup preview is suppressed. The launcher/previous surface remains visible while the engine starts, then Flutter displays the complete loading screen. The branding is fully opaque from its first frame, with a subtle 300 ms scale entrance. A two-second introduction starts after Flutter's first frame is rasterized, avoiding time lost during engine startup. This intentional branding interval does not represent a backend request. Reduced-motion mode keeps the content still for the same reading time.
- Responsive Home form, UUID validation, optional in-memory User ID reference, loading and error feedback. An **Exit** button below the footer stops voice and calls Flutter's system navigator. Android's `MainActivity.popSystemNavigator` handles this with `finishAndRemoveTask`, closing ALLY and removing its task from Recents; agent activation is not required. Exit never navigates to the splash route. Opening ALLY again starts the normal splash → Home flow.
- Backend-validated active agent and Chatbot / Voice Orb selection. Selection shows **Back** instead of Exit; it clears the active session and returns to the top of the UUID form, keeping the entered UUID editable. Exit is only shown on the UUID form. Subscription metadata and embed-session credentials are optional for public deployments.
- Chatbot with the demo-style dark welcome screen, text composer and voice button. Text-only requests use the existing NestJS text endpoint; while voice is connected, typed messages use that same live session and receive spoken replies. Both modes share the in-memory transcript.
- Live voice in Chatbot and Voice Orb: permission on tap, scoped backend credential, Gemini Live WebSocket, microphone PCM at 16 kHz, speaker PCM at 24 kHz, input/output transcripts, state feedback and stop control. Leaving either screen, backgrounding, reset and expiry release the microphone. Audio stays in memory.
- Black Voice Orb screen with a tappable orb and **Tap to start** button, introduction-first audio, live connection/speaking/listening states, cancellation, stop and retry. **Open Chatbot** ends voice and opens the shared transcript. Opening the orb screen alone never starts recording.
- Thinking and connecting animate the orb's blue highlight, soft pulse and halo ripples with a clear center. Listening and speaking have their own pulse speeds. These are state-based visual effects, not microphone volume measurements; reduced-motion settings keep the orb still.
- Known HTTP-200 backend failure phrases become typed errors instead of assistant messages. The user message remains available through “Edit last message”; requests are not automatically resent.
- Light/dark themes, safe areas, route protection, expiry handling, session reset and isolation of asynchronous responses.
- Dependency-injected repositories and HTTP client, typed errors and sanitized debug logs.

**Activation policy (15 October 2026, Asia/Manila):** activation requires a successful config response, matching Agent UUID and `data.status: "active"`. As requested, missing subscription metadata or embed credentials no longer block activation. The current GCP development API returns an active test agent with `subscriptions: null` and no token/expiry. Live activation and a greeting/reply were verified in the updated Android app, as well as with a direct API request without an Authorization header.

The inspected source checkout also supports signed embed sessions. When supplied, credentials are validated and sent with chat; expired or malformed credentials remain errors. Backend authorization and billing errors are respected in either mode. Public activation does not sign in a user or prove agent ownership. There is no mock activation switch in the shipped app. See [backend contracts](docs/backend-contracts.md).

## Run independently

Run these commands from this directory, using Flutter 3.44.8 / Dart 3.12.2 or a compatible newer stable SDK:

```powershell
flutter doctor -v
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config/dev.example.json
```

The example contains only the verified public development API address. Enter an Agent UUID in the app; none is embedded in app code or configuration.

For another environment:

```powershell
flutter run --dart-define=ALLY_API_BASE_URL=https://your-api.example/api/v1
```

Changing a dart define requires stopping and restarting the app; hot reload does not change compile-time configuration. An omitted/invalid URL produces a setup message and prevents requests.

To see the loading screen again, stop the running app (`q` in the `flutter run` terminal), then run the command above again. Hot reload (`r`) and returning to an already-open app keep the current screen. Hot restart (`R`) restarts the Flutter introduction. Android resource changes require a full stop and rebuild; hot reload/restart cannot update the native launch background.

Local NestJS networking:

| Device | API base URL |
| --- | --- |
| Standard Android emulator | `http://10.0.2.2:3000/api/v1` |
| Physical Android device on same LAN | `http://YOUR_COMPUTER_LAN_IP:3000/api/v1` |
| USB device with `adb reverse tcp:3000 tcp:3000` | `http://127.0.0.1:3000/api/v1` |

Use the actual port/path of the existing backend. For LAN access it must listen on an accessible interface and the host firewall must permit the port. `localhost` on a device normally refers to the device itself. Cleartext HTTP is enabled **only in the debug manifest**; profile/release require HTTPS. No certificate-verification bypass is installed.

## Verify and build

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/dev.example.json
flutter install -d emulator-5554 --debug
```

APK: `build/app/outputs/flutter-apk/app-debug.apk`.

Validation performed on 14–15 October 2026:

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed |
| `flutter analyze --no-pub` | Passed, no issues |
| `flutter test --no-pub` | 105 tests passed |
| Debug APK build | Passed |
| Android 15 emulator install and launch | Passed; Home visually inspected |
| Exit | Android launcher start → Home → Exit verified: ALLY closed, its task was removed from Recents, and it did not restart into splash. The focused widget test verifies voice cleanup before the platform exit call. |
| Cold-start sequence | Blue ALLY loading screen → Home; no separate blank blue preview in Android 15 emulator captures, in light and dark modes |
| Empty UUID on emulator | Correct validation message |
| Live activation on Android | HTTP 200; active agent without subscription/token opened Chatbot and Voice Orb selection |
| Successful activation, chat, selection, protected navigation | Passed with test doubles |
| Selection Back | Widget test verifies selection has Back and no Exit, then returns to the UUID form at the top with the ID editable, no splash or platform exit, and the session cleared. |
| Live chat | Direct API check and Android chat both returned real replies without an Authorization header |
| Live voice protocol | Backend credential, constrained WebSocket and real audio/transcript reply verified |
| Android live session | Permission prompt → Listening → typed live greeting → “Hello!” transcript with PCM playback → Stop verified, host microphone disabled |
| Automatic voice introduction | Updated APK: Start → Preparing introduction → real agent introduction/transcript and PCM playback → Listening → Stop verified with no user audio; host microphone disabled |
| Live Voice Orb | Tap to start → permission → introduction → Listening → Stop → shared transcript in Chatbot verified on Android; first attempt timed out, one manual retry succeeded |
| Orb thinking effects | Three rendered animation frames visually reviewed; 11 orb/widget tests passed after the update, including reduced motion and session controls. Analyzer and debug APK build passed; updated APK installed on emulator. |
| Account sign-in / physical-device speech | Sign-in not implemented; physical microphone quality/recognition still needs device testing |

The tests cover UUID formats, API verbs and headers, timeouts, error mapping, safe logs, malformed responses, active-agent validation, optional subscription/token fields, signed-session validation, public and signed chat requests, provider transitions, duplicate submissions, stale results after reset, expiry, Home behavior, protected routes, both modes, large text at 320/800 logical pixels, and all orb states with reduced motion. Automated tests use mock clients and do not depend on the live database.

Voice tests additionally cover denied/late permissions, cancelled connection setup, agent changes, shared transcripts, speaker echo suppression, playback drain, interruption cleanup, tool-call deduplication/cancellation, route exit, backgrounding, temporary-credential validation and the WebSocket wire protocol. Introduction tests cover the opening cue, microphone gating until playback finishes, queued playback, empty/timed-out responses, stopping during the greeting, and blocking appointment actions during the opening turn. Chat tests cover legacy HTTP-200 failures, manual message recovery, and the keyboard layout at 320/800 logical pixels with enlarged text.

Orb screen tests cover explicit start through either control, introduction/speaking/listening state mapping, stop/cancel, permission retry, navigation to shared chat, Android back, app background/resume, agent reset, and error/control layouts at 320/800 logical pixels with enlarged text.

The local Android SDK reported some unaccepted licenses, but the installed components were sufficient for this debug build. If a different environment needs additional components, review the licenses using `flutter doctor --android-licenses`. This is a development APK. The generated release signing configuration still uses the debug key; configure your own keystore and application identity before distribution.

## Structure

```text
ally_mobile_app/
├── android/                 # Android host, native branding and network policy
├── config/
│   └── dev.example.json     # Public dev API URL; no agent IDs or secrets
├── lib/
│   ├── main.dart            # Composition root; real repositories
│   ├── app.dart             # Provider ownership and lifecycle
│   ├── core/
│   │   ├── config/          # dart-define configuration
│   │   ├── constants/       # Verified endpoint paths
│   │   ├── errors/          # Typed failures
│   │   ├── theme/           # Colors, gradients, Material 3 themes
│   │   └── validation/     # UUID validator
│   ├── models/              # Agent session, chat message, voice state
│   ├── providers/           # Agent, chat and voice UI state
│   ├── repositories/        # Contract parsing and backend operations
│   ├── services/            # HTTP, Gemini Live socket, Android PCM audio
│   ├── routes/              # go_router and access guards
│   ├── screens/             # splash, home, chat, voice
│   └── widgets/             # common, agent, chat, voice
├── test/                    # Unit/widget tests and test-only fixtures
├── docs/backend-contracts.md
├── pubspec.yaml
├── pubspec.lock
├── analysis_options.yaml
└── README.md
```

Icons and the orb use Flutter drawing and Android vector resources. Empty raster asset directories were intentionally omitted; add `assets/icons/` or `assets/images/` and pubspec entries when actual assets exist. The startup screens follow the supplied screenshot references; other screens follow the supplied layout and color specifications.

## Dependencies

| Direct package | Resolved version | Purpose |
| --- | --- | --- |
| [provider](https://pub.dev/packages/provider) | 6.1.5+1 | UI state and dependency injection |
| [go_router](https://pub.dev/packages/go_router) | 18.0.2 | Navigation and redirects |
| [http](https://pub.dev/packages/http) | 1.6.0 | Injectable JSON HTTP client |
| [record](https://pub.dev/packages/record) | 7.1.2 | Permission and streaming microphone PCM |
| [flutter_pcm_sound](https://pub.dev/packages/flutter_pcm_sound) | 3.3.3 | Streaming PCM speaker playback |
| flutter_test (SDK, dev) | SDK | Unit and widget testing |
| flutter_lints (dev) | 6.0.0 | Static analysis conventions |

Transitive dependencies are recorded in `pubspec.lock`; no other direct runtime packages were added.

`flutter_pcm_sound` pins Android compile SDK 33. The targeted override in `android/build.gradle.kts` uses SDK 36 for that library, required by the AndroidX dependencies resolved with this Flutter version. It does not edit the global pub cache or change the app's minimum Android version.

## Using voice in Chatbot or Voice Orb

Activate an agent, open **Chatbot**, then tap the waveform button. Allow Android microphone permission. The app shows **Preparing introduction…**, plays the agent's real spoken introduction (**Introducing…**), then switches to **Listening**. An existing conversation receives a short welcome-back instead. The greeting uses the backend-configured identity and voice; its actual transcript appears in chat. No artificial user message is added.

For the orb interface, choose **Voice Orb** and tap the blue orb or **Tap to start**. It uses the same voice service, validated agent and introduction flow. The button becomes **Cancel** during connection, **Stop voice** during the session, and **Tap to retry** after failure. **Open Chatbot** stops voice and shows the conversation collected by either interface. Back navigation and backgrounding also stop voice; returning to the app does not restart recording.

Audio capture is initialized for the session, but microphone samples are discarded until the introduction's server turn and speaker playback have both finished. Wait for **Listening**, then speak or type in the same live session. Text sending waits during the introduction; **Stop voice** remains available throughout. An empty, interrupted or stalled opening fails clearly and releases audio; the opening has a 45-second timeout. Tap **Stop voice** to continue text-only chat. A denied permission leaves typing available. The app does not reconnect or resume recording automatically.

The emulator verification disabled host microphone input to avoid recording the room. To test your own speech on that emulator, enable host microphone input in its settings, or run `adb emu avd hostmicon on` when you are ready. Check media volume for spoken replies. A physical Android device is recommended for microphone, echo and headset testing. Bluetooth routing is not enabled in this phase.

Microphone transmission pauses during assistant playback to prevent speaker echo, matching the inspected demo behavior. The stop button always remains accessible. Incoming interruption events flush queued playback. Voice uses the backend's model, prompt, voice and tools; no Google API key is bundled. Tool calls use the existing appointment-action endpoint and are never automatically retried. Closing chat does not yet call the demo's analyze/submit inquiry workflow.

## Modifying and debugging

- Change brand values in `core/theme/`, reusable visuals in `widgets/`, and screen layouts in `screens/`.
- Android startup uses `windowDisablePreview` and, on Android 12+, a transient translucent **launch** theme. Modern Android launcher starts ignore `windowDisablePreview` for opaque themes, as shown in [Android's starting-window implementation](https://github.com/aosp-mirror/platform_frameworks_base/blob/android15-release/services/core/java/com/android/server/wm/ActivityRecord.java). Flutter uses an opaque `NormalTheme`; `MainActivity.onFlutterUiDisplayed` also makes the activity opaque once its first frame appears, allowing Android to release the surface behind it. Flutter retains its default surface renderer. Validate a full launcher start when changing these settings; hot reload cannot verify them. Initial engine startup still takes time, especially in debug builds.
- Android exit is handled by `MainActivity.popSystemNavigator` using [finishAndRemoveTask](https://developer.android.com/reference/android/app/Activity#finishAndRemoveTask()). Native exit changes require a rebuilt/reinstalled APK; hot reload cannot apply them. Navigation inside Chatbot and Voice Orb continues to use go_router.
- Providers own loading/error/session state. Screens contain no HTTP calls.
- Contract changes belong in repositories and models; base URL, timeouts and network behavior belong in configuration/service.
- Use Flutter DevTools to inspect Provider state and breakpoints in `ApiAgentRepository.activate` or `ChatProvider.send`.
- Debug API logs show method, route template, status, elapsed milliseconds and error kind. Hosts, UUIDs, tokens, request/response bodies, and user references are omitted. Release/profile builds emit no API logs.
- `[ALLY Chat]` logs only the error kind; `[ALLY Voice]` logs state transitions. PCM samples, transcripts and WebSocket credential URLs are not logged.
- HTTP `error=none` means the transport succeeded. Repository checks can still reject inactive/mismatched agents or malformed supplied session credentials; inspect `AgentProvider.error.kind`.
- Chat requests are never automatically retried: the backend can execute appointment tools, and a timeout may occur after processing. Failed bubbles say “Delivery unconfirmed” and are excluded from the next transcript.
- Conversation data, optional embed token and optional User ID are memory-only. Reset, signed-session expiry, backend rejection and process restart clear them. Public sessions have no invented token or expiry. App resume checks signed-session expiry. There is no silent reactivation or persistence.
- Optional User ID is not sent to an endpoint because the inspected activation/chat contracts do not consume it. It is not an account credential.

| Symptom / error kind | Check |
| --- | --- |
| Configuration | Include `/api/v1`, omit query/credentials, restart after changing dart defines |
| Network / timeout | Device internet, emulator/LAN address, firewall, backend process, valid TLS certificate |
| Unauthorized / forbidden | Backend denied access, or supplied credentials are invalid/expired; a token-required server must issue credentials in config |
| Agent / route not found | Correct Agent UUID and base path; API 404 cannot reliably distinguish the two |
| Inactive agent | Existing backend agent status |
| Inactive subscription | Backend returned HTTP 402; local subscription metadata does not gate activation |
| Unexpected response | Deployment contract mismatch, malformed JSON, empty chat reply |
| Rate limited | Wait before resubmitting; no automatic retry |
| Server unavailable | Existing NestJS logs and infrastructure; no credentials belong in this app |
| Assistant temporarily unavailable with HTTP 200 | Legacy backend fallback was detected. The 15 October failure was an upstream HTTP 503; see the confirmed diagnosis in backend-contracts.md |
| Voice / microphone | Android permission, device media volume, internet access to Gemini Live; typing remains available after voice fails |

## Backend scope and next phase

Integrated: GET `embed/config/:agentId`, POST `embed/text-message`, POST `embed/ephemeral-token`, and the voice tool relay through POST `embed/appointment-action`, relative to the configured API prefix. Mobile activation requires a successful response, active agent and matching ID. Subscription metadata is optional and does not override agent status. Embed token/expiry may both be absent; if either is supplied, both must be valid. This does not establish account identity or agent ownership.

The mobile policy follows the backend's agent status, including active agents with legacy payments or non-active subscription metadata. Billing and request authorization remain server responsibilities. No backend, database or schema changes were made.

Next: review/apply the separate [backend 503 proposal](docs/backend-text-503-proposal.patch) with explicit approval, then test longer conversations and speech on a physical phone. The proposal retries only the failed Gemini inference once after 500 ms and returns an HTTP 503 if it still fails. It never replays the enclosing chat or appointment flow. Five isolated retry checks passed and `git apply --check` passed against the inspected checkout; NestJS integration tests and deployment are pending approval. The local backend and cloud deployment were not changed.

Account sign-in, properly scoped agent picking, inquiry submission on explicit conversation completion, physical-device audio testing, and signed-session deployment checks remain follow-up work.

## Future monorepo move

Move this entire directory to `apps/mobile/ally_mobile_app/`. Keep `pubspec.lock`, source, tests, Android configuration and documentation. Run Flutter commands from the new directory. Do not move generated `build/`, `.dart_tool/`, IDE files or `android/local.properties`; regenerate machine-specific paths with Flutter. All application dependencies and configuration are independent of the Angular/NestJS filesystem. Nx wiring can be added later without changing the app.
