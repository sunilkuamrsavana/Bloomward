# Cloud sync implementation

Current app format: schema 3. See **Planner schema 3** below for tasks, daily checklists, and notes. The following schema-2 description is retained for older-account compatibility.

## Data and transport

The SwiftUI app syncs only signed-in account storage. Guest data is never uploaded or automatically merged. Synced fields are habits (including schedules/options/notes), routines, daily outcomes, completed routine runs, profile name, day/week boundaries, and new-habit defaults. Active timers, snooze deadlines, appearance, haptics, OS permissions, credentials, and welcome state remain device-local.

`SyncSnapshot` schema 2 uses arrays rather than Swift's non-string-key dictionary encoding. It adds optional routine/item schedules, nested step children, and step notes. The server accepts schemas 1 and 2; the current app reads both. Routine trees are bounded to five item levels and 1,000 nodes, validate unique IDs across branches, and reject empty/incompatible day selections. Groups cannot also be linked habits. Existing flat records decode unchanged. Version-one clients already stop on newer snapshots; an atomic server-side schema check additionally refuses downgrade writes with HTTP 426, preserving the existing revision/data. Active execution plans remain device-local. No database migration or user-data rewrite is needed.

Dates use Swift's default reference-date seconds. `GET /v1/sync` returns `{revision, snapshot, updatedAt}`; a new account gets revision 0 and a null snapshot. `PUT /v1/sync` accepts `{baseRevision, snapshot}`. Maximum request body is 512 KiB, enforced while reading, not just by Content-Length. The app retains local data if it reaches this limit.

Each request carries a fresh-enough Clerk session from the SDK. JOSE verifies RS256 against the production instance's public JWKS, exact issuer, expiry/not-before, user/session claims, pending-session status, and authorized party when present. Native tokens may omit `azp`. Neither cookies, request-body owner IDs, path IDs, nor `X-User-Id` select a user. All SQL uses the verified subject in bound statements. No Clerk API secret is needed for sync. Responses are not cached; browser CORS is not enabled. Only data payloads, revision, timestamp, and Clerk user ID are stored; credentials are not logged or stored with habits.

## Offline and concurrent edits

Local changes persist first. The app syncs on foreground entry, one second after changes, and every 30 seconds while active (including retry after reconnect). It does not promise background execution while iOS suspends it. Settings shows real sync status, last success, and manual retry.

The server's single-statement compare-and-swap is atomic. A stale writer receives 409 rather than overwriting another device. The client merges three ways against its last confirmed snapshot, by habit ID, routine ID, day/habit outcome, routine-run identity, and individual preference. Independent changes combine, including removals. Identical outcomes do not conflict. Competing edits stop sync and require a Settings choice; non-conflicting records still merge. A local pre-resolution recovery copy is retained. An upload whose response was lost is safe to retry. Changes made during network requests are preserved. Account identity is checked before and after each suspension; old-account results never enter new-account storage. Damaged local state does not upload as an empty deletion.

## Account deletion

`POST /webhooks/clerk` accepts only verified Svix/Standard Webhooks messages with timestamp validation. Subscribe the Clerk production endpoint to **user.deleted only**. Required encrypted Worker secret: `CLERK_WEBHOOK_SIGNING_SECRET` (not a Clerk API secret). The handler deletes just that user's cloud snapshot and writes a minimal deletion tombstone in one atomic D1 batch. The tombstone stops a still-valid session from recreating data. Replayed genuine deliveries are idempotent; failed deliveries return non-2xx for retry. Never test this by deleting a real user's account.

Clerk endpoint created: `ep_3JernuS2p89PLBpShkcVRSQdvvP`, URL `https://api.bloomward.inqox.com/webhooks/clerk`. The signing key was transferred with explicit user approval directly into Cloudflare's encrypted `CLERK_WEBHOOK_SIGNING_SECRET`, with no source-file or iOS-app copy.

## Operations

- Local tests use the local configuration and isolated D1 storage, never production data.
- Apply `wrangler d1 migrations apply bloomward-db --env production --remote` before deploy. Migration 0001 is additive.
- Use `wrangler deploy --env production --dry-run`, then `wrangler deploy --env production`.
- Secrets must be configured before production deploy; never replace a missing secret with a placeholder.
- Readiness checks only schema presence, not personal data.
- For failures, keep client data intact and diagnose using error status, not tokens or snapshot logs.
- No paid plan or billing changes are part of this implementation.
- Transport uses HTTPS; this is not end-to-end encryption. Public privacy/retention policies remain a release prerequisite.

## Verification

September 23 routine update: 82 Swift core tests and 38 local Workers tests pass, including nested round-trip, version-one upgrade, atomic downgrade refusal, explicit schema-version enforcement, duplicate nested IDs, bounded depth, incompatible schedules, and unchanged account isolation. Type checks and production dry run pass. Deployed Worker version `dff08a60-8c9c-420b-a60b-d8528b6bff3a`; the read-only `/ready` endpoint reports the database reachable and sync enabled. Existing bindings, encrypted secrets, authentication, and deletion handling are unchanged. Live nested sync with real credentials/two iPhones is not claimed; payload/database behavior was checked in the isolated Workers tests.

42 Swift tests pass, including merge/restore, independent offline writes, competing edits, removal propagation, in-flight edits, idempotent retry, preferences, and timer exclusion. 32 Workers-runtime tests pass, including real RSA-signed test JWT validation, account isolation, atomic competing writes, stale revisions, body/schema limits, deletion signatures, idempotent cleanup and no resurrection. Xcode simulator build passes. Physical two-iPhone testing is still recommended before release.

Production migration 0001 is applied. Cloud-sync Worker version `5a36ac2a-a270-46e7-9878-5d7d92b3b183` is deployed. Live checks on September 22, 2026: health and readiness both returned 200 with sync enabled; missing and forged bearer tokens returned 401; an unsigned webhook returned 400 `invalid_webhook_signature`. The signed simulator build was installed without resetting data. The existing account showed `Up to date` and a successful last-sync timestamp in Settings. No demo habits or real account deletions were used.

Clerk's live signed example delivery `msg_3JhPJDytglA1iImfgY4MAYRasM3` succeeded on September 22 at 3:50 PM America/Chicago. The example was `session.created`, which this handler acknowledges only after signature verification and then ignores without database writes. This confirms live delivery/signature configuration, not a live account deletion. Clerk's test UI had no schema/sample for `user.deleted`; actual deletion, replay idempotency, and tombstone behavior were verified in isolated automated tests, not against the user's production account. The production subscription remains `user.deleted` only.
# Planner schema 3 (October 10)

Schema 3 adds `planTasks`, `planOccurrences`, and `dayNotes` to the existing authenticated snapshot. Existing habits, routines, daily entries, and history remain intact for compatibility. A daily occurrence is keyed by task ID plus calendar date; note pages have independent UUIDs. Tasks and notes use the same account-scoped three-way merge and explicit conflict review. Routine checklists are captured per date so progress is not overwritten by future template changes.

The Worker accepts existing schema-1/2 accounts and schema-3 accounts. Planner arrays are required in schema 3 and forbidden in older schemas. The existing atomic revision and schema-version guards prevent older clients overwriting planner records. No D1 schema migration or existing snapshot rewrite is required. Soft removals and archived notes sync as records and can be restored in the app.

The existing 512-KiB upload limit still applies to the entire account snapshot. Individual notes allow 200-character titles and 100,000-character bodies, but the aggregate must fit that limit to sync. Local storage is retained and the app reports the unsupported backup size instead of deleting content. Moving a task creates a separate one-off at the destination, preserving the source's move marker and never overwriting another scheduled occurrence.
