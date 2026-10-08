# AI charge check

The Cloudflare worker can check that a coin charge exists before it runs an AI generation. Today the app spends coins in one call and asks for the image in a second call. The worker cannot see the first call. This feature links the two with a charge id.

## What it does

- The app sends `chargeTxId` in the body of `POST /api/ai/generations` and `POST /api/ai/generations/{id}/variations`. The value is the `transactionId` that `spendCoins` returns.
- The worker reads that ledger row from Firestore. It runs the generation only if the row is a valid payment for this user and this tier.
- A retry with the same id returns the stored image. The worker does not call the provider again.
- A public read endpoint, `GET /api/ai/charges/{txId}`, tells `awardCoins` if a charge was used. The refund path will use it as evidence.

## Where to find it

There is no screen. The code is in `infra/cloudflare/worker/src/ai.ts`. The tests are in `infra/cloudflare/worker/test/worker.test.mjs`.

## Platforms and plans

All platforms and all plans. The check does not depend on Pro. A Pro user who skips the coin charge with a bypass has no ledger row and fails the check when the flag is on.

## How it works

Flag: `AI_REQUIRE_CHARGE` in `wrangler.toml` `[vars]`. The default is `"false"`.

| Case | Flag off | Flag on |
|---|---|---|
| No `chargeTxId` | Runs as before. | 402 `charge_required`. |
| `chargeTxId` has a bad shape (not `[A-Za-z0-9_-]` and 8 to 220 characters) | 400 `invalid_request`. | 400 `invalid_request`. |
| `chargeTxId` is valid | Checked and used. | Checked and used. |

Flow for a request with a valid `chargeTxId`:

1. The worker verifies the Firebase token, parses the body, and checks the prompt. These errors (400, 422) happen before the claim.
2. The worker calls `charge_claim` on `AiQuotaCoordinator` (same Durable Object class, no new migration).
   - `new`: go to step 3.
   - `in_progress`: 409 `charge_in_progress`.
   - `done`: return the stored response. No provider call.
   - `failed`: 402 `charge_invalid`. A failed charge is closed. The app must refund it and spend again.
3. The worker reads `coinTransactions/{txId}` with the REST API. It sends the caller's own Firebase token. Firestore rules let a user read their own ledger rows. No secret is needed.
4. The row must match all of these:
   - `userId` equals the token user.
   - `action` is `aiGeneration`.
   - `type` is `debit`.
   - `status` is `completed`.
   - `-delta` equals the tier price: fast 10, balanced 75, quality 100.
   - `createdAt` is at most 15 min old.
5. On a mismatch, or a 401, 403, or 404 from Firestore, the worker releases the claim and returns 402 `charge_invalid`. On a Firestore outage it releases the claim and returns 502.
6. The worker runs the generation. It then calls `charge_finish` with `succeeded` (and the response body) or `failed`.

A variation uses the stored tier of the parent generation to find the price.

Budget guardrail: a paid request is never moved to a cheaper tier. If the guardrail would lower the tier, the worker returns 429 `budget_exhausted` and marks the charge `failed`. The app must refund it. Requests without `chargeTxId` keep the old downgrade.

Durable Object records:

- Key `charge:{txId}`. State is `in_progress`, `succeeded`, or `failed`.
- Time to live is 24 h. An expired record reads as `not_started` and is deleted when it is read.
- An `in_progress` record older than 5 min counts as `failed`. This covers a worker that stopped in the middle of a request.

Evidence endpoint: `GET /api/ai/charges/{txId}`.

- Response: `{"status": "not_started" | "in_progress" | "succeeded" | "failed"}`.
- No sign-in. The id is random and acts as the key.
- 404 when the id has a bad shape. `Cache-Control: no-store`.
- Intended rule for `awardCoins`: refund an `aiGeneration` debit only when the status is `failed` or `not_started`. Fail closed when the call fails. This server change is not part of the worker.

## Limits

- Partial. The worker side is done. The app does not send `chargeTxId` yet. The `awardCoins` refund check does not call the evidence endpoint yet. Do not turn the flag on until both ship.
- `spendCoins` ignores `status` when it replays a request id. A refunded id can still pass a replay. The worker blocks this because it requires `status` `completed`.
- `spendCoins` accepts `allowPremiumBypass` for any action. This leaves no ledger row, so a bypass fails the check when the flag is on. The functions fix is in another work package.
- Expired Durable Object records are deleted only when read. Old unread records stay in storage. Each is small.
- The 15 min window starts at the ledger `createdAt`. A request that waits longer than 15 min before the first call fails the check. A retry after a first success still works for 24 h.
- One Durable Object (`global`) holds all charge records. This matches the existing quota design.

## Other worker changes in this release

- Blocklist: prompt terms match whole words. "a bowl of grapes" passes. "rape" and "raped" fail. Multi-word terms still match.
- Share pages: titles and descriptions are escaped once. `Don't & Co` shows correctly in link previews.
- Share pages: the human page has `<meta name="apple-itunes-app">` for the iOS Smart App Banner. The button stays.
- `POST /api/links`: bodies over 8 KB return 413. `campaign` is kept only when it is a flat object with at most 10 string keys. Keys and values are at most 100 characters. Otherwise it is dropped.
- `POST /api/links` rate limit: the counter lives in the Durable Object, so it is atomic. If the Durable Object fails, the worker uses the old KV counter. Expired counters in the Durable Object stay in storage until the same key is used again. Each is small.
- `GET /api/ai/health`: without a valid Firebase token it returns `{"ok": true}`. With a token it returns the budget numbers as before.
- Short link errors (`/l/{code}` not found or bad code): the worker returns a small HTML page with the Prism name, "This link is no longer available", and an "Open Prism" store link. The status stays 404 or 400.

## Rollout order

1. Deploy the worker with `AI_REQUIRE_CHARGE = "false"`. Old clients keep working.
2. Deploy the functions that add the evidence check to refunds.
3. Release the app that sends `chargeTxId`.
4. Wait until most users run the new app.
5. Set `AI_REQUIRE_CHARGE = "true"` in `wrangler.toml` and deploy the worker. Old app builds then get 402 `charge_required`. This step is an owner decision.

New environment variable: `AI_REQUIRE_CHARGE` (plain var, `"false"` or `"true"`). No new secret. No new binding. No new migration.

## How to test

1. Run `sh tool/cloudflare-worker-check.sh`. All 33 tests must pass.
2. Charge tests: search the test file for `chargeTxId`, `charge_required`, `charge_invalid`, and `/api/ai/charges/`.
3. After deploy with the flag off, call `curl -s https://prismwalls.com/api/ai/charges/spend_test_00000001`. Expect `{"status":"not_started"}`.
4. After the app ships, spend coins for a generation. Send the returned `transactionId` as `chargeTxId`. Expect 200. Send it again. Expect the same body and no second provider cost.
5. With the flag on, call `POST /api/ai/generations` without `chargeTxId`. Expect 402 `charge_required`.
