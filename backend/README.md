# Bloomward backend

Cloudflare Workers + D1 authenticated cloud sync for the native SwiftUI app. See [SYNC.md](SYNC.md) for the protocol, offline/conflict behavior, account cleanup, deployment prerequisites, and verification.

## Deployed resources

- App home: https://bloomward.inqox.com (development placeholder only)
- API: https://api.bloomward.inqox.com
- Worker fallback: https://bloomward-api.black-poetry-4fa5.workers.dev
- Worker: `bloomward-api`
- D1: `bloomward-db` (`36fc82c4-9fa6-43b6-b1f8-3c95b2202d46`)
- Initial deployed version: `cf0af0ff-96cb-4eb4-bdf2-07769459e916`
- Cloud-sync deployed version: `5a36ac2a-a270-46e7-9878-5d7d92b3b183`

Existing applications, root-domain services, and databases are not reused.

## Checks and deployment

Use Node 24 with a compatible npm. npm 11.3.0 crashed during peer dependency resolution on this machine; installing with `npx --yes npm@11.6.0 install` succeeded. The lockfile is stored alongside this source.

```sh
npm ci
npm run check
npm run deploy:dry-run
npm run deploy:production
```

`npm run check` generates Worker types, checks source/test types, and runs 32 tests in the local Workers runtime. Local development and tests use isolated local database storage, never production. Deployment requires the existing authorized Cloudflare login and encrypted `CLERK_WEBHOOK_SIGNING_SECRET`. No Clerk API secret is needed for user-session verification.

- `GET /health`: Worker availability and sync feature status.
- `GET /ready`: read-only schema readiness; does not inspect personal data.
- `GET/PUT /v1/sync`: verified Clerk session required, account-owned snapshots with atomic revision checks.
- `POST /webhooks/clerk`: signed `user.deleted` cleanup, no unsigned deletion allowed.
- Unknown routes return 404; public endpoints reject unsupported methods.
- Responses disable caching and indexing and include security headers. No browser CORS access is granted.

## Clerk production

Created on the existing Hobby plan on September 21, 2026, without a paid upgrade.

- Application: `app_3JeaD0nRypSSsY6sLpkgRnvKpbL`
- Production instance: `ins_3JedzJp914XAMgUFFGBYcKrvaOr`
- Application domain: `bloomward.inqox.com`, configured as a secondary application beneath `inqox.com`.
- Frontend API: `https://clerk.bloomward.inqox.com`
- Account portal: `https://accounts.bloomward.inqox.com`
- Public publishable key: `pk_live_Y2xlcmsuYmxvb213YXJkLmlucW94LmNvbSQ`

The publishable key is intentionally public. No Clerk API secret key or Apple private key is stored in this project, retrieved from the dashboard, or embedded in the iOS app. With explicit user approval, the separate webhook signing key was transferred directly from Clerk to the encrypted Cloudflare Worker secret `CLERK_WEBHOOK_SIGNING_SECRET`; it is not in source files or the iOS app.

DNS records supplied by Clerk and verified in its dashboard:

| Type | Name within inqox.com | Target |
| --- | --- | --- |
| CNAME | clerk.bloomward | frontend-api.clerk.services |
| CNAME | accounts.bloomward | accounts.clerk.services |
| CNAME | clkmail.bloomward | mail.p056v5ewa9bo.clerk.services |
| CNAME | clk._domainkey.bloomward | dkim1.p056v5ewa9bo.clerk.services |
| CNAME | clk2._domainkey.bloomward | dkim2.p056v5ewa9bo.clerk.services |

All five Clerk records are DNS-only (not proxied). The user completed Cloudflare's Domain Connect flow; DNS was checked through Cloudflare and verified through Clerk. Clerk confirms both SSL certificates are issued. A live request to the Frontend API's public JWKS endpoint returned HTTP 200 over validated HTTPS. The account portal returned a Cloudflare browser challenge to the command-line check (`cf-mitigated: challenge`); its interactive sign-in flow has not been tested.

Email-code sign-in and email verification are enabled in production. Email sign-up currently requires a password (15-character minimum, compromised-password rejection on). These security settings were preserved. The user enabled Native API and registered iOS app `A9N7R3TRCA.com.inqox.bloomward`; its public AASA file was checked. Native Apple sign-in is enabled. Google was disabled with the user's approval because its production credentials were not configured. No paid upgrade was made.

The user reported registering `bounces+115308597@clkmail.bloomward.inqox.com` in Apple's private email relay settings. Successful Hide My Email delivery remains an end-to-end test item. Apple's web OAuth Services ID/private-key fields remain empty intentionally: the app uses the native flow, not web Apple OAuth. Do not use the hosted account portal as a test of native Apple sign-in.

The SwiftUI app now uses official ClerkKit and ClerkKitUI 1.5.5, the production publishable key, the registered bundle ID/team, Apple sign-in entitlement, callback URL scheme, and associated domain `webcredentials:clerk.bloomward.inqox.com`. The user completed native sign-in. On September 22, the cloud-sync build was installed over the existing simulator app without uninstalling or resetting its data. Settings showed the existing signed-in account, `Up to date`, and a successful sync timestamp. Guest mode remains local-only; no demo habits were added.

## Remaining release checks

1. Run a signed physical-iPhone test: Apple (including Hide My Email), email sign-up/verification, returning sign-in, incorrect/expired codes, resend, MFA if enrolled, cancellation, offline errors, sign-out, deletion, and session restoration. Real user consent and credentials are needed for these tests.
2. Confirm both Apple capabilities and development provisioning on the physical device. The user's Apple portal screenshots confirmed the registered identifiers and Apple sign-in selection; simulator signing is not a test of device provisioning.
3. Add a real Apple server-to-server notification handler before setting that URL or releasing account services. Do not point Apple at a placeholder endpoint.
4. Test sync on two physical iPhones, including offline changes, conflicting edits, and restoration. Server-side token validation, per-user ownership, migrations, and account-isolated cloud sync are implemented and deployed; automated tests cover these behaviors.
5. Publish real support/privacy/terms information before release; the placeholder app home is not a legal policy.

Current official references:

- [Clerk iOS quickstart](https://clerk.com/docs/ios/getting-started/quickstart)
- [Native Sign in with Apple](https://clerk.com/docs/ios/guides/configure/auth-strategies/sign-in-with-apple)
- [Cloudflare Worker custom domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
- [Workers runtime testing](https://developers.cloudflare.com/workers/testing/vitest-integration/write-your-first-test/)
