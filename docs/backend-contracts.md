# Verified ALLY backend contracts

Inspected the available local checkout of [HumAIn-PH/ai-receptionist-monorepo](https://github.com/HumAIn-PH/ai-receptionist-monorepo), clean at commit `5398959dbecc6411439293bf919c8a3c8c5b82b0`, on 14 October 2026. The public GitHub page was unavailable without authentication; conclusions come from source inspection, not an assumed API. No backend, Angular, database or schema files were changed.

## Source evidence

Paths below are relative to the existing monorepo, not mobile dependencies:

| Source | Finding |
| --- | --- |
| `apps/backend/api/src/main.ts` | Global prefix `api`, URI version `1`; default local port 3000 |
| `apps/frontend/demo-site/src/app/shared/embed-widget/embed-widget.ts` | GET config; accepts `status=success` and agent `status=active` |
| `apps/frontend/demo-site/src/app/services/agent-session.service.ts` | Stores entered UUID and optional User ID |
| `apps/frontend/demo-site/src/app/shared/global-embed/global-embed.ts` | Passes UUID and optional User ID in iframe URL |
| `apps/backend/api/src/app/embed/embed.controller.ts` | Public config, signed-session text and appointment endpoints |
| `apps/backend/api/src/app/embed/embed-session.ts` | 30-minute agent-bound embed JWT; Bearer verification |
| `apps/backend/api/src/app/embed/embed.service.ts` | UUID/config lookup, JSON text response, Gemini Live token issuance |
| `libs/models/src/lib/constants/select-fields.const.ts` | Agent fields, nullable `subscriptions` relation, subscription `status` |
| `libs/embed-core/src/lib/services/genai.service/gen-aiservice.ts` | Actual Angular text/voice request construction |
| `apps/backend/api/src/app/agent/agent.controller.ts` and `agent.service.ts` | JWT-protected management endpoints and ownership filters |
| `apps/backend/api/src/app/jwt/jwt.strategy.ts` | Supabase ES256/JWKS Bearer authentication |
| `apps/backend/api/src/app/auth/auth.controller.ts` and `auth.service.ts` | Backend-mediated Supabase sign-in and refresh |
| `apps/backend/api/src/app/subscription/subscription.service.ts` | Subscription changes update agent status; past-due can remain active |

## Activation: implemented

`GET /api/v1/embed/config/:agentId` (version-neutral `/api/embed/config/:agentId` is also declared).

No account Bearer token is required by this public embed route. `getConfig` validates the UUID using `isUUID(agentId, 'all')`, looks up the agent through Prisma and returns its selected metadata. It does **not** perform account-owner authorization or independently enforce subscription status.

Relevant response subset from source (illustrative values, not live credentials):

```json
{
  "status": "success",
  "message": "Config retrieved",
  "data": {
    "id": "<agent UUID>",
    "name": "<actual agent name>",
    "status": "active",
    "subscriptions": {
      "id": "<subscription UUID>",
      "status": "active",
      "nextBillingSchedule": "<date or null>",
      "pricing": {}
    }
  },
  "embedToken": "<server-issued token>",
  "embedTokenExpiresAt": 0
}
```

The example timestamp is a placeholder. When credentials are supplied, the client requires a real future timestamp in milliseconds. The local controller issues token fields only when the returned agent is active. Issuance requires a backend `EMBED_SESSION_SECRET` of at least 32 UTF-8 bytes. This secret must remain on the backend. The current deployed public API omits both credential fields; this is also supported by mobile.

The token has agent subject, random session ID, embed scope, issuer `humain-embed`, audience `humain-embed-api` and a 30-minute expiry. The backend verifies the JWT for text requests. Mobile does not pretend to verify the server signature or treat the UUID as permission.

Under the revised requirement of 15 October 2026, mobile activation requires a successful config response, matching agent ID and exactly `status: "active"`. Subscription data is optional metadata; missing subscriptions, legacy payments and non-active subscription metadata do not block an otherwise active agent. Billing schedules are not treated as entitlement expiry dates.

Both embed token and expiry may be absent/null for the public deployment. No credentials or expiration are fabricated. If either field is present, require a nonempty token and future expiry (over 30 seconds, no more than one hour); malformed, partial and expired credentials remain errors. Signed sessions expire in memory; public sessions last until reset, process restart or a backend rejection. A UUID alone still does not activate anything without the backend config check.

This is public assistant/embed access, not authenticated account access. The optional User ID is stored only as a local reference because neither config nor text-message consumes it. An account-scoped flow must use actual sign-in and server authorization.

## Text chat: signed and public deployment support

`POST /api/v1/embed/text-message`

JSON content type is always sent. When a config-issued token exists, send `Authorization: Bearer <embedToken>`. With public config that omits both credentials, omit Authorization entirely. Never retry a rejected signed request without its token. The inspected local source requires a token; the currently deployed API also accepts the public request, verified with a greeting on 15 October 2026.

```json
{
  "receptionistId": "<validated agent UUID>",
  "transcript": [
    {"sender": "user", "text": "Hello"},
    {"sender": "assistant", "text": "How can I help?"},
    {"sender": "user", "text": "What are your hours?"}
  ],
  "userMessage": "What are your hours?"
}
```

The backend also supports `agentId`; both IDs must match if both are sent. Mobile mirrors Angular's `receptionistId` body and transcript snapshot, including the current user message. It sends no invented conversation ID. Prior messages live in Provider memory.

Response: `{"text":"<assistant response>"}`. This inspected route is a normal JSON POST, not an SSE/streaming contract. The backend calls Gemini and can run appointment tools internally. Mobile does not implement separate appointments, inquiry submission or analysis APIs.

A notable backend limitation: some Gemini failures or inactive-agent checks return HTTP 200 with generic `text`. Mobile now recognizes the three exact fallback strings found in `EmbedService.sendTextMessage`, raises `assistantUnavailable`, retains the user message as failed/unconfirmed, and excludes the fallback from conversation history. It does not infer errors from arbitrary assistant prose. “Edit last message” restores the text for an explicit user retry; there is no automatic POST replay.

Signed-session expiry returns users to activation. Backend 401/402/403/404 responses invalidate either session type. Network failures retain the conversation with an unconfirmed-delivery marker. No automatic POST retry occurs.

## Authenticated agent access: discovered, not exposed as a picker

| Endpoint | Inspected behavior |
| --- | --- |
| `GET /api/v1/agent` | JwtGuard, but service queries all agents without per-user filtering |
| `GET /api/v1/agent/client/:id` | JwtGuard; service filters on supplied client ID without comparing it to current user |
| `GET /api/v1/agent/:id` | JwtGuard; service filters by `createdById=req.user.id` and excludes deleted agents |
| `POST /api/v1/auth/sign-in` | Backend calls Supabase password sign-in, returns `data.session` |
| `POST /api/v1/auth/refresh-token` | Receives refreshToken; returns refreshed access/refresh tokens |
| `GET /api/v1/subscription/:id` and `/subscription/user/:id` | JWT-protected subscription management routes; not used by public embed activation |

No clearly safe “agents accessible to the current authenticated user” listing contract was established from the two listing implementations. Their JWT guards alone do not establish row-level authorization. This app does not use a caller-entered User ID to retrieve agents or claim ownership. Review server-side scoping before adding a picker.

The backend uses Prisma for database operations and Supabase for account authentication. A direct mobile Supabase dependency is unnecessary for the implemented embed flow. Mobile account login, secure persistent token storage and refresh lifecycle remain future work.

## Voice: shared live transport in Chatbot and Voice Orb

`POST /api/v1/embed/ephemeral-token`, body `{"receptionistId":"<agent UUID>"}` (or `agentId`).

The local controller has rate limiting but no signed embed-session/account guard on this route. The inspected service checks existence, constructs server-scoped Gemini Live configuration, and issues a single-use token. Active-subscription enforcement is not evident on this path. Review this before a mobile voice release; no server change was made.

Response includes `token` (an `auth_tokens/...` credential), `expiry`, `newSessionExpiry`, `voiceModel`, `voiceName`, `voiceEmpathy` and `n8nConfigured`. Existing server settings allow a 30-minute lifetime and a one-minute new-session window.

Angular uses Google GenAI Live, streaming PCM input at 16 kHz and playback at 24 kHz, audio transcription, activity detection, tool calls and interruption management. These browser Web Audio APIs are not portable Flutter audio transport.

Chatbot and Voice Orb call this endpoint through the same VoiceProvider after an explicit start tap and microphone permission. They validate `auth_tokens/` credentials, the model name, and both expiry fields. Public deployment requests omit Authorization; signed deployments retain their embed credential. The token never goes to storage or logs.

The transport connects to `wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContentConstrained` using the temporary token as `access_token`, then sends only `setup.model`. Prompt, voice and tool configuration stay locked by the backend credential. The connection becomes ready after `setupComplete`, not merely a socket open. This follows the [official WebSocket contract](https://ai.google.dev/gemini-api/docs/live-api/get-started-websocket).

`record` streams mono PCM16 at 16 kHz through `realtimeInput.audio`. `flutter_pcm_sound` plays PCM16 at 24 kHz from `serverContent.modelTurn.parts[].inlineData`. `inputTranscription` and `outputTranscription` update shared chat bubbles. Text typed while connected uses `clientContent`; completed prior chat history is synchronized when voice begins. Voice-off typing continues to use NestJS text-message. Failed text turns are excluded from history synchronization.

On each explicit voice start, after setup/history synchronization and audio initialization, the mobile provider sends one `clientContent` greeting cue (`turnComplete: true`). This follows the existing Angular `startWithGreeting` / `sendGreetingTurn` mechanism. It asks for a brief spoken introduction in the configured persona, or a welcome-back when completed chat history exists. It does not replace the scoped system prompt or add a synthetic user bubble. Only the returned assistant transcription appears in chat. Microphone frames are discarded and text submission waits until the opening turn completes and queued speaker playback drains. A missing, interrupted or timed-out introduction releases the session with a retry message; the timeout is 45 seconds. Opening-turn tool calls receive a no-action response without calling the appointment backend.

Voice tool calls reuse `POST /api/v1/embed/appointment-action` with `{receptionistId, toolName, toolArgs}` and optional embed Authorization, then return `{id,name,response:{output:result}}` to Gemini. The backend validates/executes all actions. Call IDs are deduplicated within a session; cancelled or stale results are discarded. No tool/appointment action is automatically retried. Live appointment execution was not exercised during verification; the contract and routing were mock-tested.

Voice cleanup closes capture/playback/socket on stop, route exit, app background, agent reset, credential expiry and connection failure. No automatic reconnect or background capture. Input transmission pauses during speaker playback as an echo guard. Remote interruption flushes playback. Voice Orb's **Tap to start** control and tappable orb use these same operations and real provider states, including the introduction-first flow. Opening Chatbot from the orb stops voice and preserves the shared agent/transcript; no duplicate transport, backend endpoint or audio dependency was added.

The app does not yet run the demo's end-of-conversation `analyze`/`submit` workflow, which can send notifications. Bluetooth routing, physical-device speech quality and full-duplex interruption remain follow-up work.

## Error conventions

NestJS uses standard status codes and JSON exception bodies. Many management services use `{status,statusCode,message,data}`, with `throwOnError` converting failures to HTTP exceptions. Mobile supports both HTTP failures and legacy error envelopes. It does not surface raw backend messages or log response data.

Malformed success payloads are rejected as unexpected responses. HTTP 404 is intentionally described as agent-or-route not found because the wire response status alone cannot distinguish configuration errors from missing agents.

## Development deployment check

The user supplied `https://humain-ally-dev.web.app/`. Its public JavaScript bundle identified:

`https://ai-receptionist-monorepo-dev-498707583822.asia-south1.run.app/api/v1`

Read-only checks of the supplied test UUID returned:

- HTTP 200, envelope `success`.
- Matching UUID, nonempty agent name, agent `status=active`.
- `subscriptions` field present with value `null`.
- Root fields only `status`, `message`, `data`; no embed token/expiry.

The earlier APK rejected this response under the original strict subscription policy. The revised mobile activation accepts it under the user's active-agent policy. On 15 October 2026, a manual POST to the existing text endpoint, with one greeting and no Authorization header, returned a nonempty 207-character response rather than the known generic failure text. No token, full configuration, personal metadata or real UUID was saved in source. No appointment or voice request was made. The development API is not proven to be running the inspected commit.

The updated Android APK also activated that agent, displayed the assistant selection, sent a greeting and displayed the backend's real reply. The emulator logged HTTP 200 for both config and text-message. This verifies the current public deployment for activation and text chat without subscription metadata or session credentials. A deployment that requires signed sessions must return usable credentials in config; backend authorization failures are never bypassed.

On 15 October, the existing voice endpoint issued a scoped credential for `gemini-3.8-live`. A text-only live protocol probe completed a turn with PCM output and transcription. The Android app subsequently showed the microphone permission dialog, connected to Listening, sent a harmless typed greeting through that live session, received “Hello!” with PCM playback, returned to Listening, and stopped successfully. The emulator host microphone was disabled; recording was limited to its virtual input. Android's app-ops check showed recording had ended. This does not verify physical microphone recognition, speaker sound quality, headset behavior or real appointment tools.

The automatic-introduction update was also verified on the Android emulator on 15 October: one explicit Start Voice produced the configured agent's spoken self-introduction and actual transcript without user speech or typing. The UI moved from Preparing introduction to Introducing, then Listening after PCM playback drained. Stop returned to text chat. Host microphone input remained disabled. Flutter analysis passed, all 93 tests passed, and the updated debug APK built successfully.

The subsequent live Voice Orb update passed 103 tests and static analysis and built/installed successfully. The emulator's **Tap to start** opened Android's permission prompt and connected through the same provider. The first live opening received no audio before the 45-second timeout, which released recording and exposed **Tap to retry**. One manual retry returned the agent's introduction, played PCM audio, and reached Listening. Stop ended recording (confirmed with Android app-ops), and **Open Chatbot** displayed the real introduction in the shared transcript. Host microphone input was disabled. This confirms orb activation/playback/cleanup; it does not establish physical-device speech recognition or eliminate intermittent live-service failures.

## Confirmed text failure and proposed backend fix

The user supplied Cloud Run application logs for the failing chat: at **15 October 2026, 09:58:23 UTC+8** (`01:58:23Z`), `EmbedService` logged `sendTextMessage: Gemini call failed` followed by `Request failed with status code 503`. The outward mobile request was HTTP 200 because the catch block converted the failure into assistant text. The user confirmed the same symptom on the demo. This points to the upstream service call, not a mobile base URL, UUID-format or database-connection problem. The provided line does not reveal why the upstream service returned 503.

Two later harmless REST text turns succeeded; this does not prove the intermittent outage is fixed. Voice credential issuance and a live greeting also succeeded. The deployed revision reported by the user is `ai-receptionist-monorepo-dev-00053-nkr`, commit `1327b10f9f25dd3bbb6dfd7f40b3c09c30dc9ce9`, which differs from the inspected local checkout.

[`backend-text-503-proposal.patch`](backend-text-503-proposal.patch) is a **proposal only**, not applied to NestJS or deployed. It retries a single Gemini `generateContent` call once after 500 ms on HTTP 503 only, adds a 10-second per-attempt timeout, logs only the upstream numeric status, and returns a real HTTP 503 after exhaustion. Retry wraps inference inside the tool loop, not the outer chat handler, so already executed appointment actions are not replayed by the retry. Other status codes and ambiguous network errors are not retried. It cannot guarantee recovery from an ongoing provider outage.

The patch includes Jest helper tests. Five isolated Node checks of its retry helper passed, including a simulated inference-after-tool case; `git apply --check` passed against the local backend checkout. Full NestJS integration tests, comparison with the deployed revision, applying the patch, and deployment remain pending explicit backend approval. No Angular, NestJS, database, schema, or cloud deployment change was made during this mobile update.
