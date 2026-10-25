import * as admin from "firebase-admin";

const AMOUNT = 1000;
const ACTION = "adminTestCoins";
const SOURCE_TAG = "coins.admin_test_grant.cli";
const REASON = "qa_test_grant";

export const USAGE = "Usage: node lib/scripts/grantTestCoins.js " +
  "--project <project-id> --uid <uid> --grant-id <unique-id> [--apply]";

export function parseGrantTestCoinsArgs(argv: readonly string[]) {
  const values = new Map<string, string>();
  let apply = false;
  for (let i = 0; i < argv.length; i++) {
    const flag = argv[i];
    if (flag === "--apply" && !apply) {
      apply = true;
    } else if (["--project", "--uid", "--grant-id"].includes(flag) && !values.has(flag)) {
      const value = argv[++i];
      if (!value || value.startsWith("--")) throw new Error(`Missing value for ${flag}. ${USAGE}`);
      if (value.trim() !== value) throw new Error(`Unsafe argument value for ${flag}. ${USAGE}`);
      values.set(flag, value);
    } else {
      throw new Error(`Unknown or duplicate argument: ${flag}. ${USAGE}`);
    }
  }
  const projectId = values.get("--project");
  const uid = values.get("--uid");
  const grantId = values.get("--grant-id");
  if (!projectId || !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(projectId)) {
    throw new Error(`An explicit 6-30 character project ID is required. ${USAGE}`);
  }
  if (!uid || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) {
    throw new Error(`An explicit UID using 1-128 letters, digits, underscores or hyphens is required. ${USAGE}`);
  }
  if (!grantId || !/^[A-Za-z0-9][A-Za-z0-9_-]{7,63}$/.test(grantId)) {
    throw new Error(`An explicit grant ID using 8-64 letters, digits, underscores or hyphens is required. ${USAGE}`);
  }
  return {projectId, uid, grantId, apply};
}

function counter(value: unknown, field: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${field} must be a nonnegative safe integer; refusing to repair it.`);
  }
  return value;
}

/** Operator-only. Never export this script from index.ts or expose it through a callable. */
export async function grantTestCoins(
  app: admin.app.App,
  options: ReturnType<typeof parseGrantTestCoinsArgs>,
) {
  if (app.options.projectId !== options.projectId) throw new Error("Admin SDK project does not match --project.");
  const authUser = await app.auth().getUser(options.uid);
  if (authUser.uid !== options.uid || authUser.disabled) throw new Error("Auth user is mismatched or disabled.");

  // common initializes the default app. Load it only after the CLI has selected its explicit project.
  const {coinTransactionDoc} = await import("../common.js");
  const db = app.firestore();
  const userRef = db.doc(`usersv2/${options.uid}`);
  const privateRef = db.doc(`usersv2/${options.uid}/private/economy`);
  // Project-wide key: reusing a grant ID for another UID must fail, not issue another grant.
  const id = `ctx_adminTestCoins_${options.grantId}`;
  const receiptRef = db.doc(`coinTransactions/${id}`);
  return db.runTransaction(async (tx) => {
    const [userSnap, privateSnap, receiptSnap] = await Promise.all([
      tx.get(userRef), tx.get(privateRef), tx.get(receiptRef),
    ]);
    const user = userSnap.data();
    if (!userSnap.exists || !user || user.deleted === true) throw new Error("Active usersv2 document not found.");
    const balance = counter(user.coins, "usersv2.coins");
    const privateData = privateSnap.data() ?? {};
    const rev = counter(privateData.rev === undefined ? 0 : privateData.rev, "private/economy.rev");
    const identity = {
      uid: authUser.uid,
      authEmail: authUser.email ?? null,
      authDisplayName: authUser.displayName ?? null,
      profileEmail: typeof user.email === "string" ? user.email : null,
      profileUsername: typeof user.username === "string" ? user.username : null,
    };
    const target = {projectId: options.projectId, identity, grantId: options.grantId, transactionId: id};
    const receipt = receiptSnap.data();
    if (receiptSnap.exists) {
      if (!receipt || receipt.id !== id || receipt.userId !== options.uid ||
          receipt.projectId !== options.projectId || receipt.grantId !== options.grantId ||
          receipt.delta !== AMOUNT || receipt.action !== ACTION || receipt.sourceTag !== SOURCE_TAG ||
          receipt.reason !== REASON || receipt.status !== "completed" || receipt.type !== "credit" ||
          !(receipt.createdAt instanceof admin.firestore.Timestamp) ||
          !(receipt.updatedAt instanceof admin.firestore.Timestamp)) {
        throw new Error("Grant receipt mismatch; refusing replay.");
      }
      const before = counter(receipt.balanceBefore, "receipt.balanceBefore");
      const after = counter(receipt.balanceAfter, "receipt.balanceAfter");
      const revBefore = counter(receipt.revBefore, "receipt.revBefore");
      const revAfter = counter(receipt.revAfter, "receipt.revAfter");
      if (after - before !== AMOUNT || revAfter - revBefore !== 1) {
        throw new Error("Grant receipt mismatch; refusing replay.");
      }
      return {...target, outcome: "already-applied", dryRun: !options.apply, delta: 0,
        currentBalance: balance, currentRev: rev, grantBalanceBefore: before, grantBalanceAfter: after};
    }

    const balanceAfter = counter(balance + AMOUNT, "resulting coins");
    const revAfter = counter(rev + 1, "resulting rev");
    if (options.apply) {
      tx.update(userRef, {coins: balanceAfter});
      tx.set(privateRef, {rev: revAfter}, {merge: true});
      tx.create(receiptRef, {
        ...coinTransactionDoc({id, userId: options.uid, at: admin.firestore.Timestamp.now(), delta: AMOUNT,
          balanceBefore: balance, action: ACTION, description: "Operator test coins (+1000)",
          sourceTag: SOURCE_TAG, reason: REASON}),
        projectId: options.projectId, grantId: options.grantId, revBefore: rev, revAfter,
      });
    }
    return {...target, outcome: options.apply ? "applied" : "would-apply", dryRun: !options.apply,
      delta: AMOUNT, balanceBefore: balance, balanceAfter, revBefore: rev, revAfter};
  });
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  if (argv.length === 1 && argv[0] === "--help") {
    console.log(USAGE);
    return;
  }
  const options = parseGrantTestCoinsArgs(argv);
  const app = admin.initializeApp({projectId: options.projectId});
  try {
    console.log(JSON.stringify(await grantTestCoins(app, options), null, 2));
  } finally {
    await app.delete();
  }
}

if (require.main === module) {
  void main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
