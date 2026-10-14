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

The example timestamp is a placeholder; the client requires a real future timestamp in milliseconds. The local controller issues token fields only when the returned agent is active. Issuance requires a backend `EMBED_SESSION_SECRET` of at least 32 UTF-8 bytes. This secret must remain on the backend.

The token has agent subject, random session ID, embed scope, issuer `humain-embed`, audience `humain-embed-api` and a 30-minute expiry. The backend verifies the JWT for text requests. Mobile does not pretend to verify the server signature or treat the UUID as permission.

Mobile acceptance additionally requires matching agent ID, active linked subscription and a nonempty token with a future expiry (over 30 seconds, no more than one hour). Missing subscriptions, legacy-payment-only agents, past-due and other non-active subscription states remain locked. Billing schedules are not treated as entitlement expiry dates.

This is public assistant/embed access, not authenticated account access. The optional User ID is stored only as a local reference because neither config nor text-message consumes it. An account-scoped flow must use actual sign-in and server authorization.

## Text chat: implemented against source, live success pending

`POST /api/v1/embed/text-message`

Header: `Authorization: Bearer <embedToken>`, JSON content type.

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

A notable backend limitation: some Gemini failures or inactive-agent checks return HTTP 200 with a generic `text` response. The mobile client displays that real response; it cannot reliably distinguish provider failure from ordinary assistant prose without a backend contract change. Transport errors never create fake assistant messages.

Session expiry returns users to activation. A 401/403/404 invalidates the session. Network failures retain the conversation with an unconfirmed-delivery marker. No automatic POST retry occurs.

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

## Voice: source inspected, transport intentionally pending

`POST /api/v1/embed/ephemeral-token`, body `{"receptionistId":"<agent UUID>"}` (or `agentId`).

The local controller has rate limiting but no signed embed-session/account guard on this route. The inspected service checks existence, constructs server-scoped Gemini Live configuration, and issues a single-use token. Active-subscription enforcement is not evident on this path. Review this before a mobile voice release; no server change was made.

Response includes `token` (an `auth_tokens/...` credential), `expiry`, `newSessionExpiry`, `voiceModel`, `voiceName`, `voiceEmpathy` and `n8nConfigured`. Existing server settings allow a 30-minute lifetime and a one-minute new-session window.

Angular uses Google GenAI Live, streaming PCM input at 16 kHz and playback at 24 kHz, audio transcription, activity detection, tool calls and interruption management. These browser Web Audio APIs are not portable Flutter audio transport.

The mobile orb accepts idle/connecting/listening/thinking/speaking/error/disconnected visual states. The production screen only displays idle preview, explicitly says the microphone is off, and never requests a voice token. No microphone permission or audio package was added.

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

The final APK reproduced the request and subscription rejection on the Android emulator. No token, full configuration, personal metadata or real UUID was saved in source. No live chat, appointment or voice request was made. The development API is not proven to be running the inspected commit.

Before successful live integration testing, the existing backend deployment needs the inspected embed-session behavior and a test agent with an active linked subscription. These are external prerequisites, not completed mobile functionality. Backend deployment changes, entitlement policy changes and schema changes require separate approval.
