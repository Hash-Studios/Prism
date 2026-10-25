# Grant test coins

This operator-only Admin SDK CLI adds exactly 1000 coins to one existing test
user. It is not a callable, client debug bypass, reward action or subscription
change. There is no amount flag. Do not export it from `functions/src/index.ts`.

## Check the target first

Use Node 24 and authorized Application Default Credentials with Firebase Auth
read and Firestore transaction permissions. Credentials are not CLI arguments.
Admin SDK access bypasses Firestore rules. Restrict it to trusted operators.
The CLI cannot determine whether a UID belongs to a test account. The operator
must confirm that identity and obtain approval before applying a grant.

From the repository root:

```sh
cd functions
npm ci
npm run build
node lib/scripts/grantTestCoins.js --project PROJECT_ID --uid TEST_UID --grant-id QA_GRANT_ID
```

Replace all placeholders. An explicit Google Cloud project ID is required, not
a Firebase alias, project number, ambient default or `.firebaserc` selection.
Project IDs use 6-30 lowercase letters, digits or hyphens, start with a letter
and end with a letter or digit. UIDs use 1-128 letters, digits, underscores or
hyphens. Grant IDs use 8-64 of those characters and start with a letter or digit.
Whitespace, paths, unknown flags, repeated flags and positional arguments fail.
`--help` alone prints usage without contacting Firebase.

The default is a dry run. It reads Auth, the user, private economy and receipt,
but writes nothing. Check the JSON output for `projectId`, `identity.uid`, Auth
email/display name, profile email/username, `grantId`, and `transactionId`.
Confirm the identity against the QA session. An anonymous Auth user can have no
email. Stop if the project or identity is not the intended test account.
`balanceBefore`, `balanceAfter`, `revBefore` and `revAfter` show the proposal.

Only after explicit approval, repeat the exact command with `--apply`:

```sh
node lib/scripts/grantTestCoins.js --project PROJECT_ID --uid TEST_UID --grant-id QA_GRANT_ID --apply
```

Keep the same grant ID for retries, including after a timeout or uncertain
response. A new grant ID authorizes another 1000 coins. Do not change it merely
because the first response was lost. Re-run the original dry-run command to
check the receipt, then refresh the QA app and confirm its balance and Activity.
A dry run is a snapshot, not a reservation. Apply re-reads the current balance.

## Storage and retry contract

One Firestore transaction reads all three documents before any write:

- `usersv2/<uid>` must exist, not be marked deleted, and have nonnegative safe
  integer `coins`. Only `coins` changes, by +1000.
- `usersv2/<uid>/private/economy` preserves every existing field and increments
  `rev` by one. A missing document or absent `rev` starts at zero. Malformed
  revisions, malformed balances and overflowing results fail without repair.
- `coinTransactions/ctx_adminTestCoins_<grant-id>` is created using the existing
  `coinTransactionDoc` contract. It records timestamps, UID, +1000 delta,
  before/after balances, completed credit status, `action: adminTestCoins`,
  `sourceTag: coins.admin_test_grant.cli`, `reason: qa_test_grant`, project ID,
  grant ID and before/after revisions.

The grant ID is unique across the project, not just per user. A matching receipt
returns `already-applied` and `delta: 0`, with no writes, even after later coin
spending. Reusing the ID for another UID or finding an inconsistent receipt
fails. A new grant returns `would-apply` in dry-run or `applied` after commit.
Failures exit nonzero. Never manually delete a receipt to retry.

Auth lookup must succeed for the same UID and the account must not be disabled.
Auth lookup is outside the Firestore transaction; Auth and Firestore do not
support a shared atomic transaction. The Firestore user, balance, revision and
receipt are checked together inside the transaction.

The CLI does not modify XP, weekly XP, quests, rank, inventory, premium,
subscriptions, passes, spin counters, coin reward state, or any other field.
It does not call `awardCoins` and does not mint reward or quest progress.

## Local proof

```sh
cd functions
npm run build
node --test lib/__tests__/grantTestCoins.test.js
```

The focused tests use the repository's in-memory Firestore and stub Auth lookup.
They do not contact live Firebase. They cover dry-run, exact grant/receipt,
untouched economic fields, concurrent calls, transaction callback retries,
atomic write failures, receipt mismatches, invalid state and CLI validation.
