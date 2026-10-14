# ALLY Mobile

Independent Flutter Android client for the existing HumAIn PH ALLY platform. Material 3, Provider, go_router and http; no Nx, new backend, database, direct Supabase SDK, microphone or upload packages.

## Current delivery

- One visible app introduction: the blue ALLY loading screen with a small translucent microphone badge, ALLY title, creator subtitle and pale spinner, followed by Home. The separate Android startup preview is suppressed. The launcher/previous surface remains visible while the engine starts, then Flutter displays the complete loading screen. The branding is fully opaque from its first frame, with a subtle 300 ms scale entrance. A two-second introduction starts after Flutter's first frame is rasterized, avoiding time lost during engine startup. This intentional branding interval does not represent a backend request. Reduced-motion mode keeps the content still for the same reading time.
- Responsive Home form, UUID validation, optional in-memory User ID reference, loading and error feedback.
- Subscription-verified session and Chatbot / Voice Orb selection.
- Text chat connected to the **inspected** NestJS contract, with distinct message bubbles, keyboard-aware composer, pending and failed delivery states.
- Black Voice Orb screen, animated blue orb, seven visual states, reduced-motion support, explicit preview status. No live microphone or audio transport.
- Light/dark themes, safe areas, route protection, expiry handling, session reset and isolation of asynchronous responses.
- Dependency-injected repositories and HTTP client, typed errors and sanitized debug logs.

**Live deployment limitation (14 October 2026, Asia/Manila):** the supplied development site resolves to the API in `config/dev.example.json`. A read-only request for the supplied test agent returned HTTP 200, `data.status: "active"`, `data.subscriptions: null`, and no `embedToken` or `embedTokenExpiresAt`. This was also reproduced through the Android emulator. Activation deliberately remains locked. A UUID or active agent flag alone does not authorize the mobile session.

The source checkout contains a newer signed embed-session contract. Live activation/chat success has **not** been verified. The complete success flow is verified with test-only mock responses. There is no mock activation switch in the shipped app. See [backend contracts and prerequisites](docs/backend-contracts.md).

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

Validation performed on 14 October 2026:

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed |
| `flutter analyze --no-pub` | Passed, no issues |
| `flutter test --no-pub` | 51 tests passed |
| Debug APK build | Passed |
| Android 15 emulator install and launch | Passed; Home visually inspected |
| Cold-start sequence | Blue ALLY loading screen → Home; no separate blank blue preview in Android 15 emulator captures, in light and dark modes |
| Empty UUID on emulator | Correct validation message |
| Live activation HTTP request on emulator | HTTP 200; correctly blocked on missing subscription |
| Successful activation, chat, selection, protected navigation | Passed with test doubles |
| Live chat / account sign-in / microphone transport | Not verified / not implemented as described below |

The tests cover UUID formats, API verbs and headers, timeouts, error mapping, safe logs, malformed responses, subscription/session gates, provider transitions, duplicate submissions, stale results after reset, expiry, Home behavior, protected routes, both modes, large text at 320/800 logical pixels, and all orb states with reduced motion. No tests depend on the live database.

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
│   ├── providers/           # Agent and chat UI state
│   ├── repositories/        # Contract parsing and backend operations
│   ├── services/            # Central HTTP client
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
| flutter_test (SDK, dev) | SDK | Unit and widget testing |
| flutter_lints (dev) | 6.0.0 | Static analysis conventions |

Transitive dependencies are recorded in `pubspec.lock`; no other direct runtime packages were added.

## Modifying and debugging

- Change brand values in `core/theme/`, reusable visuals in `widgets/`, and screen layouts in `screens/`.
- Android startup uses `windowDisablePreview` and, on Android 12+, a transient translucent **launch** theme. Modern Android launcher starts ignore `windowDisablePreview` for opaque themes, as shown in [Android's starting-window implementation](https://github.com/aosp-mirror/platform_frameworks_base/blob/android15-release/services/core/java/com/android/server/wm/ActivityRecord.java). Flutter uses an opaque `NormalTheme`; `MainActivity.onFlutterUiDisplayed` also makes the activity opaque once its first frame appears, allowing Android to release the surface behind it. Flutter retains its default surface renderer. Validate a full launcher start when changing these settings; hot reload cannot verify them. Initial engine startup still takes time, especially in debug builds.
- Providers own loading/error/session state. Screens contain no HTTP calls.
- Contract changes belong in repositories and models; base URL, timeouts and network behavior belong in configuration/service.
- Use Flutter DevTools to inspect Provider state and breakpoints in `ApiAgentRepository.activate` or `ChatProvider.send`.
- Debug API logs show method, route template, status, elapsed milliseconds and error kind. Hosts, UUIDs, tokens, request/response bodies, and user references are omitted. Release/profile builds emit no API logs.
- HTTP `error=none` means the transport succeeded. Repository checks can still reject a successful HTTP response for missing subscription/session evidence; inspect `AgentProvider.error.kind`.
- Chat requests are never automatically retried: the backend can execute appointment tools, and a timeout may occur after processing. Failed bubbles say “Delivery unconfirmed” and are excluded from the next transcript.
- Conversation data, embed token and optional User ID are memory-only. Reset, expiry and process restart clear them. App resume checks expiry. There is no silent reactivation or persistence.
- Optional User ID is not sent to an endpoint because the inspected activation/chat contracts do not consume it. It is not an account credential.

| Symptom / error kind | Check |
| --- | --- |
| Configuration | Include `/api/v1`, omit query/credentials, restart after changing dart defines |
| Network / timeout | Device internet, emulator/LAN address, firewall, backend process, valid TLS certificate |
| Unauthorized / forbidden | Missing/expired embed token, deployment of session contract, server configuration |
| Agent / route not found | Correct Agent UUID and base path; API 404 cannot reliably distinguish the two |
| Inactive agent | Existing backend agent status |
| Inactive subscription | Linked subscription must be exactly `active` |
| Subscription unverified | Backend returned null/missing subscription; do not infer entitlement from UUID/status |
| Unexpected response | Deployment contract mismatch, malformed JSON, empty chat reply |
| Rate limited | Wait before resubmitting; no automatic retry |
| Server unavailable | Existing NestJS logs and infrastructure; no credentials belong in this app |

## Backend scope and next phase

Integrated: GET `embed/config/:agentId` and POST `embed/text-message`, relative to the configured API prefix. The current mobile activation requires an active agent, an explicitly active linked subscription, matching ID and usable signed-session response. It does not establish account identity or agent ownership.

The existing demo allows some cases (such as an active agent associated with `past_due` billing or legacy payments) that this app deliberately rejects under the requested active-subscription requirement. A backend change would be required to make authoritative subscription enforcement apply to all clients; none was made.

Next: align the approved development deployment with the inspected session contract and provide a test agent with an active linked subscription; then verify real activation/chat, token expiry and backend error behavior. Account sign-in and a properly scoped agent picker can follow using the existing NestJS/Supabase auth flow. Live voice requires a separately tested Android audio transport, permissions, Gemini Live connection lifecycle, playback and interruption handling. Add audio packages only during that phase.

## Future monorepo move

Move this entire directory to `apps/mobile/ally_mobile_app/`. Keep `pubspec.lock`, source, tests, Android configuration and documentation. Run Flutter commands from the new directory. Do not move generated `build/`, `.dart_tool/`, IDE files or `android/local.properties`; regenerate machine-specific paths with Flutter. All application dependencies and configuration are independent of the Angular/NestJS filesystem. Nx wiring can be added later without changing the app.
