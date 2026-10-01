import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {awardCoins, processReferral, referralSkipReason, spendCoins, unlockPremiumPreview} from "../coinsCallables";
import {
  base64DecodedBytes,
  githubPutFile,
  isAllowedImageContent,
  isWallSubmissionUpload,
  reserveUploadSlot,
  weekStartUtc,
} from "../githubContent";
import {claimSyncSlot, syncSubscription} from "../syncSubscription";

type Doc = Record<string, unknown>;

function referralLedgerQuery(snapshot: Record<string, Doc> | Map<string, Doc>) {
  const entries = snapshot instanceof Map ? [...snapshot.entries()] : Object.entries(snapshot);
  const docs = entries
    .filter(([path, data]) => path.startsWith("coinTransactions/") && data.userId != null &&
      data.action === "referral" && data.reason === "inviter_reward")
    .map(([path, data]) => ({id: path.split("/").pop() ?? "", data: () => data}));
  return {docs, size: docs.length, empty: docs.length === 0};
}

/** In-memory Firestore: dotted update keys write nested maps. `walls` only answers the email lookup. */
function fakeStore(t: TestContext, seed: Record<string, Doc>, walls: Doc[] = []) {
  const store = new Map<string, Doc>(Object.entries(seed));
  const snap = (path: string) => ({exists: store.has(path), data: () => store.get(path)});
  const set = (path: string, data: Doc) => void store.set(path, {...data});
  let wrote = false;
  const update = (path: string, data: Doc) => {
    wrote = true;
    const doc = {...(store.get(path) ?? {})} as Doc;
    for (const [key, value] of Object.entries(data)) {
      const parts = key.split(".");
      let target = doc;
      for (const part of parts.slice(0, -1)) {
        target[part] = {...((target[part] as Doc) ?? {})};
        target = target[part] as Doc;
      }
      target[parts[parts.length - 1]] = value;
    }
    store.set(path, doc);
  };
  const tx = {
    get: async (ref: admin.firestore.DocumentReference | admin.firestore.Query) => {
      if (wrote) throw new Error("Firestore transaction reads must precede writes");
      return typeof (ref as admin.firestore.DocumentReference).path === "string" ?
        snap((ref as admin.firestore.DocumentReference).path) : referralLedgerQuery(store);
    },
    set: (ref: admin.firestore.DocumentReference, data: Doc) => {
      wrote = true;
      set(ref.path, data);
    },
    update: (ref: admin.firestore.DocumentReference, data: Doc) => update(ref.path, data),
  };
  t.mock.method(db, "runTransaction", async (cb: (tx: unknown) => Promise<unknown>) => {
    wrote = false;
    return cb(tx);
  });
  const realCollection = db.collection.bind(db);
  t.mock.method(db, "collection", (name: string) => {
    if (name !== "walls" && name !== "githubUploads") return realCollection(name);
    return {
      where: (field: string, _op: string, value: unknown) => {
        const rows: Doc[] = name === "walls" ? walls : [...store.entries()]
          .filter(([path]) => path.startsWith("githubUploads/"))
          .map(([, data]) => data);
        const docs = rows.filter((data) => data[field] === value)
          .map((data, index) => ({id: `doc${index}`, data: () => data}));
        const query = {docs, empty: docs.length === 0, get: async () => ({docs, empty: docs.length === 0})};
        return {limit: () => query, get: query.get};
      },
    };
  });
  return store;
}

function fakeRetriedStore(t: TestContext, first: Record<string, Doc>, retry: Record<string, Doc>) {
  let snapshot = first;
  const transaction = () => {
    let wrote = false;
    return {
      get: async (ref: admin.firestore.DocumentReference | admin.firestore.Query) => {
        if (wrote) throw new Error("Firestore transaction reads must precede writes");
        if (typeof (ref as admin.firestore.DocumentReference).path !== "string") return referralLedgerQuery(snapshot);
        return {
          exists: Object.prototype.hasOwnProperty.call(snapshot, (ref as admin.firestore.DocumentReference).path),
          data: () => snapshot[(ref as admin.firestore.DocumentReference).path],
        };
      },
      set: () => {
        wrote = true;
      },
      update: () => {
        wrote = true;
      },
    };
  };
  t.mock.method(db, "runTransaction", async (cb: (tx: unknown) => Promise<unknown>) => {
    await cb(transaction());
    snapshot = retry;
    return cb(transaction());
  });
}

function mockAuthCreationTimes(t: TestContext, creationTimes: Record<string, number>) {
  t.mock.method(admin.auth(), "getUser", async (userId: string) => ({
    metadata: {creationTime: iso(creationTimes[userId])},
  } as never));
}

function inviterHistory(inviterUid: string, createdAt: number[]): Record<string, Doc> {
  const docs: Record<string, Doc> = {};
  createdAt.forEach((at, index) => {
    docs[`coinTransactions/historic-${index}`] = {
      userId: inviterUid,
      action: "referral",
      reason: "inviter_reward",
      type: "credit",
      status: "completed",
      delta: 100,
      createdAt: admin.firestore.Timestamp.fromMillis(at),
    };
  });
  return docs;
}

const NOW = Date.now();
const DAY = 86_400_000;
const iso = (ms: number) => new Date(ms).toISOString();
function withWallsRepo(t: TestContext) {
  const priorRepo = process.env.GH_REPO_WALLS;
  const priorOwner = process.env.GH_USERNAME;
  process.env.GH_REPO_WALLS = "walls";
  process.env.GH_USERNAME = "owner";
  t.after(() => {
    if (priorRepo === undefined) delete process.env.GH_REPO_WALLS;
    else process.env.GH_REPO_WALLS = priorRepo;
    if (priorOwner === undefined) delete process.env.GH_USERNAME;
    else process.env.GH_USERNAME = priorOwner;
  });
}
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (fn: {run: (r: any) => Promise<any>}, req: Record<string, unknown>) => fn.run(req);

// Referral

test("referralSkipReason: allows a new caller with an older inviter under the caps", () => {
  assert.equal(referralSkipReason(iso(NOW - DAY), iso(NOW - 30 * DAY), {}, "2026-01-01", NOW), null);
});

test("referralSkipReason: rejects a caller older than 14 days or with no createdAt", () => {
  assert.equal(referralSkipReason(iso(NOW - 15 * DAY), iso(NOW - 90 * DAY), {}, "d", NOW), "referral_caller_not_new");
  assert.equal(referralSkipReason(undefined, iso(NOW - 90 * DAY), {}, "d", NOW), "referral_caller_not_new");
});

test("referralSkipReason: reads Timestamp-like createdAt values", () => {
  const ts = (ms: number) => ({toMillis: () => ms});
  assert.equal(referralSkipReason(ts(NOW - DAY), ts(NOW - 5 * DAY), {}, "d", NOW), null);
});

test("referralSkipReason: permits an account at the 14-day boundary", () => {
  assert.equal(referralSkipReason(NOW - 14 * DAY, NOW - 30 * DAY, {}, "d", NOW), null);
});

test("referralSkipReason: inviter must be older than the caller", () => {
  assert.equal(referralSkipReason(iso(NOW - 2 * DAY), iso(NOW - DAY), {}, "d", NOW), "referral_inviter_not_older");
  assert.equal(referralSkipReason(iso(NOW - 2 * DAY), undefined, {}, "d", NOW), "referral_inviter_not_older");
});

test("referralSkipReason: caps inviter rewards at 10 a day and 100 in total", () => {
  const caller = iso(NOW - DAY);
  const inviter = iso(NOW - 30 * DAY);
  assert.equal(referralSkipReason(caller, inviter, {day: "d", count: 9, total: 9}, "d", NOW), null);
  assert.equal(referralSkipReason(caller, inviter, {day: "d", count: 10, total: 10}, "d", NOW), "referral_inviter_daily_limit");
  assert.equal(referralSkipReason(caller, inviter, {day: "old", count: 10, total: 50}, "d", NOW), null);
  assert.equal(referralSkipReason(caller, inviter, {day: "d", count: 0, total: 100}, "d", NOW), "referral_inviter_lifetime_limit");
  assert.equal(referralSkipReason(caller, inviter, {day: "d", count: 10, total: 100}, "d", NOW), "referral_inviter_lifetime_limit");
});

test("processReferral: pays both users once and counts it against the inviter", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - DAY, inviter: NOW - 40 * DAY});
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 40 * DAY)},
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.changed, true);
  assert.equal(store.get("usersv2/caller")?.coins, 100);
  assert.equal(store.get("usersv2/inviter")?.coins, 105);
  assert.equal(store.get("referralStats/inviter")?.total, 1);
});

test("processReferral: an old caller gets nothing and nobody is paid", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - 60 * DAY, inviter: NOW - 400 * DAY});
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - 60 * DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 400 * DAY)},
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.changed, false);
  assert.equal(result.reason, "referral_caller_not_new");
  assert.equal(store.get("usersv2/caller")?.coins, 0);
  assert.equal(store.get("usersv2/inviter")?.coins, 5);
  assert.deepEqual(store.get("referralStats/inviter"), {
    day: new Date(NOW).toISOString().slice(0, 10), count: 0, total: 0,
  });
  // A permanent skip is marked processed, so a retry reports already processed.
  const retry = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(retry.reason, "referral_already_processed");
  assert.equal(store.get("usersv2/inviter")?.coins, 5);
});

test("processReferral: a self referral is still rejected", async (t) => {
  fakeStore(t, {});
  await assert.rejects(() => run(processReferral, {auth: {uid: "a"}, data: {inviterUserId: "a"}}), {code: "invalid-argument"});
});

test("processReferral: rejects an inviter value that is not a document ID", async (t) => {
  fakeStore(t, {});
  await assert.rejects(
    () => run(processReferral, {auth: {uid: "a"}, data: {inviterUserId: "nested/id"}}),
    {code: "invalid-argument"},
  );
});

test("processReferral: the inviter's 11th reward of the day is skipped", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - DAY, inviter: NOW - 40 * DAY});
  const day = new Date(NOW).toISOString().slice(0, 10);
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 40 * DAY)},
    "referralStats/inviter": {day, count: 10, total: 10},
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.reason, "referral_inviter_daily_limit");
  assert.equal(store.get("usersv2/inviter")?.coins, 5);
  // A daily limit is temporary, so the caller can retry tomorrow.
  assert.notEqual((store.get("usersv2/caller")?.coinState as {referralRewarded?: boolean} | undefined)?.referralRewarded, true);
});

test("processReferral: a permanent lifetime cap takes precedence over the daily cap", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - DAY, inviter: NOW - 40 * DAY});
  const day = new Date(NOW).toISOString().slice(0, 10);
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 40 * DAY)},
    "referralStats/inviter": {day, count: 10, total: 100},
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.reason, "referral_inviter_lifetime_limit");
  assert.equal((store.get("usersv2/caller")?.coinState as Doc).referralRewarded, true);
});

test("processReferral: ignores a forged recent profile createdAt", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - 30 * DAY, inviter: NOW - 400 * DAY});
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 400 * DAY)},
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.reason, "referral_caller_not_new");
  assert.equal(store.get("usersv2/caller")?.coins, 0);
  assert.equal(store.get("usersv2/inviter")?.coins, 5);
});

test("processReferral: ignores a forged old inviter profile createdAt", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - DAY, inviter: NOW - DAY / 2});
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 400 * DAY)},
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.reason, "referral_inviter_not_older");
  assert.equal(store.get("usersv2/caller")?.coins, 0);
  assert.equal(store.get("usersv2/inviter")?.coins, 5);
});

test("processReferral: a retry at the daily cap returns the skip result", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - DAY, inviter: NOW - 40 * DAY});
  const day = new Date(NOW).toISOString().slice(0, 10);
  fakeRetriedStore(t, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 40 * DAY)},
    "referralStats/inviter": {day, count: 9, total: 9},
  }, {
    "usersv2/caller": {coins: 0, createdAt: iso(NOW - DAY)},
    "usersv2/inviter": {coins: 5, createdAt: iso(NOW - 40 * DAY)},
    "referralStats/inviter": {day, count: 10, total: 10},
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.success, false);
  assert.equal(result.changed, false);
  assert.equal(result.delta, 0);
  assert.equal(result.reason, "referral_inviter_daily_limit");
});

test("processReferral: bootstraps the lifetime cap from 100 historical inviter rewards", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - DAY, inviter: NOW - 400 * DAY});
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0}, "usersv2/inviter": {coins: 10},
    ...inviterHistory("inviter", Array.from({length: 100}, (_, index) => NOW - (index + 2) * DAY)),
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.reason, "referral_inviter_lifetime_limit");
  assert.equal(store.get("referralStats/inviter")?.total, 100);
  assert.equal((store.get("usersv2/caller")?.coinState as Doc).referralRewarded, true);
  assert.equal(store.get("usersv2/inviter")?.coins, 10);
});

test("processReferral: bootstraps the current UTC daily cap and leaves the caller retryable", async (t) => {
  mockAuthCreationTimes(t, {caller: NOW - DAY, inviter: NOW - 400 * DAY});
  const day = new Date(NOW).toISOString().slice(0, 10);
  const store = fakeStore(t, {
    "usersv2/caller": {coins: 0}, "usersv2/inviter": {coins: 10},
    ...inviterHistory("inviter", Array.from({length: 10}, () => NOW - 60_000)),
  });
  const result = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(result.reason, "referral_inviter_daily_limit");
  assert.deepEqual(store.get("referralStats/inviter"), {day, count: 10, total: 10});
  assert.notEqual((store.get("usersv2/caller")?.coinState as Doc | undefined)?.referralRewarded, true);
});

test("processReferral: excludes prior-day history, reaches 100, then stops a concurrent retry", async (t) => {
  const day = new Date(NOW).toISOString().slice(0, 10);
  mockAuthCreationTimes(t, {caller: NOW - DAY, nextCaller: NOW - DAY, inviter: NOW - 400 * DAY});
  const seed = {
    "usersv2/caller": {coins: 0}, "usersv2/nextCaller": {coins: 0}, "usersv2/inviter": {coins: 10},
    ...inviterHistory("inviter", Array.from({length: 99}, (_, index) => NOW - (index + 2) * DAY)),
  };
  const store = fakeStore(t, seed);
  const paid = await run(processReferral, {auth: {uid: "caller"}, data: {inviterUserId: "inviter"}});
  assert.equal(paid.changed, true);
  assert.deepEqual(store.get("referralStats/inviter"), {day, count: 1, total: 100});

  const replayStore = {
    ...seed,
    "usersv2/nextCaller": {coins: 0},
    "referralStats/inviter": {day, count: 1, total: 100},
  };
  fakeRetriedStore(t, seed, replayStore);
  const replay = await run(processReferral, {auth: {uid: "nextCaller"}, data: {inviterUserId: "inviter"}});
  assert.equal(replay.success, false);
  assert.equal(replay.changed, false);
  assert.equal(replay.reason, "referral_inviter_lifetime_limit");
});

// Refund

function refundStore(t: TestContext, extra: Record<string, Doc> = {}) {
  return fakeStore(t, {
    "usersv2/u": {coins: 10},
    "coinTransactions/tx1": {
      userId: "u", type: "debit", status: "completed", action: "wallpaperDownload", delta: -5,
      createdAt: admin.firestore.Timestamp.fromMillis(Date.now() - 60_000),
    },
    ...extra,
  });
}
const refundReq = {auth: {uid: "u"}, data: {action: "refund", sourceTag: "t", transactionId: "tx1"}};

test("awardCoins refund: credits once and counts it toward the daily cap", async (t) => {
  const store = refundStore(t);
  const result = await run(awardCoins, refundReq);
  assert.equal(result.changed, true);
  assert.equal(store.get("usersv2/u")?.coins, 15);
  assert.equal(store.get("coinTransactions/tx1")?.status, "refunded");
  assert.equal(store.get(`coinRefundDaily/u_${new Date().toISOString().slice(0, 10)}`)?.count, 1);
  await assert.rejects(() => run(awardCoins, refundReq), {code: "failed-precondition"});
});

test("awardCoins refund: the sixth refund of the day is skipped and the debit stays completed", async (t) => {
  const day = new Date().toISOString().slice(0, 10);
  const store = refundStore(t, {[`coinRefundDaily/u_${day}`]: {day, count: 5}});
  const result = await run(awardCoins, refundReq);
  assert.equal(result.changed, false);
  assert.equal(result.reason, "refund_daily_limit");
  assert.equal(store.get("usersv2/u")?.coins, 10);
  assert.equal(store.get("coinTransactions/tx1")?.status, "completed");
});

test("awardCoins refund: rejects transaction IDs that are not document IDs", async (t) => {
  fakeStore(t, {});
  await assert.rejects(
    () => run(awardCoins, {...refundReq, data: {...refundReq.data, transactionId: "nested/id"}}),
    {code: "invalid-argument"},
  );
});

test("awardCoins refund: a retry at the daily cap returns the skip result", async (t) => {
  const day = new Date(NOW).toISOString().slice(0, 10);
  const debit = {
    userId: "u", type: "debit", status: "completed", action: "wallpaperDownload", delta: -5,
    createdAt: admin.firestore.Timestamp.fromMillis(NOW - 60_000),
  };
  fakeRetriedStore(t, {
    "usersv2/u": {coins: 10}, "coinTransactions/tx1": debit, [`coinRefundDaily/u_${day}`]: {day, count: 4},
  }, {
    "usersv2/u": {coins: 10}, "coinTransactions/tx1": debit, [`coinRefundDaily/u_${day}`]: {day, count: 5},
  });
  const result = await run(awardCoins, refundReq);
  assert.equal(result.success, false);
  assert.equal(result.changed, false);
  assert.equal(result.delta, 0);
  assert.equal(result.reason, "refund_daily_limit");
});

test("spendCoins: a retry with insufficient balance returns the retry result", async (t) => {
  fakeRetriedStore(t, {"usersv2/u": {coins: 10}}, {"usersv2/u": {coins: 0}});
  const result = await run(spendCoins, {
    auth: {uid: "u"}, data: {action: "premiumFilter", sourceTag: "t"},
  });
  assert.equal(result.success, false);
  assert.equal(result.changed, false);
  assert.equal(result.delta, 0);
  assert.equal(result.currentBalance, 0);
  assert.equal(result.insufficientBalance, true);
  assert.equal(result.transactionId, "");
});

test("awardCoins and spendCoins: prototype action names are unsupported", async (t) => {
  fakeStore(t, {"usersv2/u": {coins: 100}});
  await assert.rejects(
    () => run(awardCoins, {auth: {uid: "u"}, data: {action: "constructor", sourceTag: "t"}}),
    {code: "invalid-argument"},
  );
  await assert.rejects(
    () => run(spendCoins, {auth: {uid: "u"}, data: {action: "constructor", sourceTag: "t"}}),
    {code: "invalid-argument"},
  );
});

// One-time awards

test("awardCoins firstWallpaperUpload: skips when the caller has no wall", async (t) => {
  withWallsRepo(t);
  const store = fakeStore(t, {"usersv2/u": {coins: 0}}, []);
  const req = {auth: {uid: "u", token: {email: "a@b.c"}}, data: {action: "firstWallpaperUpload", sourceTag: "t"}};
  const skipped = await run(awardCoins, req);
  assert.equal(skipped.reason, "first_upload_no_wall");
  assert.equal(store.get("usersv2/u")?.coins, 0);
});

test("awardCoins firstWallpaperUpload: pays 50 when a wall by the caller exists", async (t) => {
  withWallsRepo(t);
  const store = fakeStore(t, {
    "usersv2/u": {coins: 0},
    "githubUploads/thumb-sha": {uid: "u", repo: "walls", path: "thumb_a.jpg"},
  }, [{
    email: "a@b.c", wallpaper_thumb: "https://raw.githubusercontent.com/owner/walls/main/thumb_a.jpg", review: false,
  }]);
  const req = {auth: {uid: "u", token: {email: "a@b.c"}}, data: {action: "firstWallpaperUpload", sourceTag: "t"}};
  const paid = await run(awardCoins, req);
  assert.equal(paid.delta, 50);
  assert.equal(store.get("usersv2/u")?.coins, 50);
});

test("awardCoins firstWallpaperUpload: rejects a forged wall row without caller upload evidence", async (t) => {
  withWallsRepo(t);
  const store = fakeStore(t, {"usersv2/u": {coins: 0}}, [{
    email: "a@b.c", wallpaper_thumb: "https://raw.githubusercontent.com/owner/walls/main/thumb_fake.jpg", review: false,
  }]);
  const req = {auth: {uid: "u", token: {email: "a@b.c"}}, data: {action: "firstWallpaperUpload", sourceTag: "t"}};
  const result = await run(awardCoins, req);
  assert.equal(result.reason, "first_upload_no_wall");
  assert.equal(store.get("usersv2/u")?.coins, 0);
});

test("awardCoins firstWallpaperUpload: rejects upload receipts from another GitHub owner", async (t) => {
  withWallsRepo(t);
  const store = fakeStore(t, {
    "usersv2/u": {coins: 0},
    "githubUploads/fake-sha": {uid: "u", repo: "walls", path: "thumb_fake.jpg"},
  }, [{
    email: "a@b.c", wallpaper_thumb: "https://raw.githubusercontent.com/attacker/walls/main/thumb_fake.jpg", review: false,
  }]);
  const req = {auth: {uid: "u", token: {email: "a@b.c"}}, data: {action: "firstWallpaperUpload", sourceTag: "t"}};
  assert.equal((await run(awardCoins, req)).reason, "first_upload_no_wall");
  assert.equal(store.get("usersv2/u")?.coins, 0);
});

test("awardCoins firstWallpaperUpload: accepts an approved legacy wall without an upload receipt", async (t) => {
  const priorRepo = process.env.GH_REPO_WALLS;
  const priorOwner = process.env.GH_USERNAME;
  delete process.env.GH_REPO_WALLS;
  delete process.env.GH_USERNAME;
  t.after(() => {
    if (priorRepo !== undefined) process.env.GH_REPO_WALLS = priorRepo;
    if (priorOwner !== undefined) process.env.GH_USERNAME = priorOwner;
  });
  const store = fakeStore(t, {"usersv2/u": {coins: 0}}, [{email: "a@b.c", review: true}]);
  const req = {auth: {uid: "u", token: {email: "a@b.c"}}, data: {action: "firstWallpaperUpload", sourceTag: "t"}};
  assert.equal((await run(awardCoins, req)).delta, 50);
  assert.equal(store.get("usersv2/u")?.coins, 50);
});

const completeProfile = {
  coins: 0, profilePhoto: "https://x/p.png", username: "neo", bio: "hi", links: {twitter: "https://t/neo"},
};
const profileReq = {auth: {uid: "u"}, data: {action: "profileCompletion", sourceTag: "t"}};

test("awardCoins profileCompletion: pays when photo, username, bio and a link are filled", async (t) => {
  const store = fakeStore(t, {"usersv2/u": completeProfile});
  assert.equal((await run(awardCoins, profileReq)).delta, 25);
  assert.equal(store.get("usersv2/u")?.coins, 25);
});

test("awardCoins profileCompletion: skips each missing field", async (t) => {
  for (const patch of [{bio: " "}, {username: ""}, {links: {a: ""}}, {profilePhoto: ""}]) {
    const store = fakeStore(t, {"usersv2/u": {...completeProfile, ...patch}});
    const result = await run(awardCoins, profileReq);
    assert.equal(result.reason, "profile_incomplete");
    assert.equal(store.get("usersv2/u")?.coins, 0);
  }
});

// Premium preview unlock

const unlockReq = {auth: {uid: "u"}, data: {collectionKey: " Neon "}};

test("unlockPremiumPreview: charges 10, writes the unlock and the ledger in one transaction", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {coins: 30}});
  const result = await run(unlockPremiumPreview, unlockReq);
  assert.equal(result.changed, true);
  assert.equal(result.delta, -10);
  assert.equal(store.get("usersv2/u")?.coins, 20);
  const unlocks = (store.get("usersv2/u")?.coinState as Doc).premiumPreviewUnlocks as Record<string, number>;
  assert.ok(unlocks.neon > Date.now() + 23 * 3_600_000);
  const ledger = [...store.entries()].find(([k]) => k.startsWith("coinTransactions/"))?.[1];
  assert.equal(ledger?.action, "premiumPreview24h");
  assert.equal(ledger?.delta, -10);
});

test("unlockPremiumPreview: a second call while unlocked is free", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {coins: 30}});
  await run(unlockPremiumPreview, unlockReq);
  const again = await run(unlockPremiumPreview, unlockReq);
  assert.equal(again.success, true);
  assert.equal(again.changed, false);
  assert.equal(again.reason, "premium_preview_already_unlocked");
  assert.equal(store.get("usersv2/u")?.coins, 20);
});

test("unlockPremiumPreview: an expired unlock is charged again", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {coins: 30, coinState: {premiumPreviewUnlocks: {neon: Date.now() - 1}}}});
  assert.equal((await run(unlockPremiumPreview, unlockReq)).changed, true);
  assert.equal(store.get("usersv2/u")?.coins, 20);
});

test("unlockPremiumPreview: a prototype key is charged and persisted as an own property", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {coins: 30}});
  const constructor = await run(unlockPremiumPreview, {auth: {uid: "u"}, data: {collectionKey: "constructor"}});
  assert.equal(constructor.changed, true);
  const again = await run(unlockPremiumPreview, {auth: {uid: "u"}, data: {collectionKey: "constructor"}});
  assert.equal(again.changed, false);
  const unlocks = (store.get("usersv2/u")?.coinState as Doc).premiumPreviewUnlocks as Record<string, number>;
  assert.equal(Object.prototype.hasOwnProperty.call(unlocks, "constructor"), true);
  assert.equal(store.get("usersv2/u")?.coins, 20);
  await assert.rejects(
    () => run(unlockPremiumPreview, {auth: {uid: "u"}, data: {collectionKey: "__proto__"}}),
    {code: "invalid-argument"},
  );
});

test("unlockPremiumPreview: insufficient balance changes nothing", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {coins: 9}});
  const result = await run(unlockPremiumPreview, unlockReq);
  assert.equal(result.insufficientBalance, true);
  assert.equal(result.success, false);
  assert.equal(store.get("usersv2/u")?.coinState, undefined);
  assert.equal(store.get("usersv2/u")?.coins, 9);
});

test("unlockPremiumPreview: premium users unlock without a charge", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {coins: 0, premium: true}});
  const result = await run(unlockPremiumPreview, unlockReq);
  assert.equal(result.bypassed, true);
  assert.equal(result.changed, false);
  assert.equal(store.get("usersv2/u")?.coins, 0);
});

test("unlockPremiumPreview: needs sign-in and a key", async (t) => {
  fakeStore(t, {});
  await assert.rejects(() => run(unlockPremiumPreview, {data: {collectionKey: "a"}}), {code: "unauthenticated"});
  await assert.rejects(() => run(unlockPremiumPreview, {auth: {uid: "u"}, data: {}}), {code: "invalid-argument"});
});

test("spendCoins still works for the other spend actions", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {coins: 10}});
  await run(spendCoins, {auth: {uid: "u"}, data: {action: "premiumFilter", sourceTag: "t"}});
  assert.equal(store.get("usersv2/u")?.coins, 5);
});

// GitHub uploads

const b64 = (bytes: number[] | string) => Buffer.from(bytes as never, typeof bytes === "string" ? "latin1" : undefined).toString("base64");
const ftyp = (brand: string) => "\0\0\0\x18ftyp" + brand + "\0\0\0\0";

test("isAllowedImageContent: accepts JPEG, PNG, GIF, WebP, HEIC/HEIF and AVIF signatures", () => {
  const accepted = [
    b64([0xff, 0xd8, 0xff, 0xe0]),
    b64([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0]),
    b64("GIF87a\0\0"),
    b64("GIF89a\0\0"),
    b64("RIFF\x01\0\0\0WEBPVP8 "),
    ...["heic", "heix", "hevc", "heim", "heis", "mif1", "msf1", "avif"].map((brand) => b64(ftyp(brand))),
  ];
  for (const payload of accepted) assert.equal(isAllowedImageContent(payload), true, payload);
});

test("isAllowedImageContent: rejects text, zip, html, svg, empty and unknown ftyp brands", () => {
  const rejected = [
    b64("hello world, this is text"),
    b64("PK\x03\x04\0\0\0\0\0\0\0\0"),
    b64("<html><body>x</body></html>"),
    b64("<svg xmlns='http://www.w3.org/2000/svg'/>"),
    b64("RIFF\x01\0\0\0WAVEfmt "),
    b64(ftyp("mp42")),
    b64([0xff, 0xd8]),
    "",
  ];
  for (const payload of rejected) assert.equal(isAllowedImageContent(payload), false, payload);
});

test("base64DecodedBytes: matches the decoded size", () => {
  for (const n of [0, 1, 2, 3, 100, 1001]) {
    assert.equal(base64DecodedBytes(Buffer.alloc(n, 1).toString("base64")), n);
  }
});

test("weekStartUtc: returns the Monday of the week", () => {
  assert.equal(weekStartUtc(Date.parse("2026-10-01T12:00:00Z")), "2026-09-28");
  assert.equal(weekStartUtc(Date.parse("2026-10-04T23:59:00Z")), "2026-09-28");
  assert.equal(weekStartUtc(Date.parse("2026-10-05T00:00:00Z")), "2026-10-05");
});

test("isWallSubmissionUpload: only thumb_ files in the walls repo count", () => {
  const env = {GH_REPO_WALLS: "walls", GH_REPO_SETUPS: "setups"};
  assert.equal(isWallSubmissionUpload("walls", "thumb_a.jpg", env), true);
  assert.equal(isWallSubmissionUpload("walls", "a.jpg", env), false);
  assert.equal(isWallSubmissionUpload("setups", "thumb_a.jpg", env), false);
});

function putReq(data: Record<string, unknown>) {
  return {auth: {uid: "u"}, data: {repo: "walls", message: "m", contentBase64: "/9j/", path: "a.jpg", ...data}};
}

test("githubPutFile: rejects non-image bytes (even named .jpg), bad base64 and oversize files before Firestore", async (t) => {
  process.env.GH_REPO_WALLS = "walls";
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not reserve a slot");
  });
  for (const payload of [b64("<html>not an image</html>"), b64("PK\x03\x04zip"), b64("plain text")]) {
    await assert.rejects(() => run(githubPutFile, putReq({path: "evil.jpg", contentBase64: payload})), {
      code: "invalid-argument", message: "Only image files are allowed.",
    });
  }
  await assert.rejects(() => run(githubPutFile, putReq({contentBase64: "/9j/!"})), {code: "invalid-argument"});
  const big = Buffer.alloc(15 * 1024 * 1024 + 1).toString("base64");
  await assert.rejects(() => run(githubPutFile, putReq({contentBase64: big})), {code: "invalid-argument"});
});

test("githubPutFile: a real JPEG named .heic passes validation", async (t) => {
  process.env.GH_REPO_WALLS = "walls";
  t.mock.method(db, "runTransaction", () => {
    throw new Error("reached slot reservation");
  });
  await assert.rejects(() => run(githubPutFile, putReq({path: "photo.heic"})), /reached slot reservation/);
});

test("reserveUploadSlot: stops at 30 uploads a day", async (t) => {
  const day = new Date(NOW).toISOString().slice(0, 10);
  fakeStore(t, {"githubUploadStats/u": {day, count: 29}});
  await reserveUploadSlot("u", false, NOW);
  await assert.rejects(() => reserveUploadSlot("u", false, NOW), {code: "resource-exhausted"});
});

test("reserveUploadSlot: the daily cap resets on a new day", async (t) => {
  fakeStore(t, {"githubUploadStats/u": {day: "2000-01-01", count: 30}});
  await reserveUploadSlot("u", false, NOW);
});

test("reserveUploadSlot: profile uploads never count toward the weekly wall quota", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {}});
  for (let i = 0; i < 10; i++) assert.equal(await reserveUploadSlot("u", false, NOW), false);
  assert.equal(store.get("githubUploadStats/u")?.weekCount, 0);
});

test("reserveUploadSlot: a free user gets 3 wall previews a week", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {premium: false}});
  for (let i = 0; i < 3; i++) assert.equal(await reserveUploadSlot("u", true, NOW), true);
  await assert.rejects(() => reserveUploadSlot("u", true, NOW), {code: "resource-exhausted"});
  assert.equal(store.get("githubUploadStats/u")?.weekCount, 3);
});

test("reserveUploadSlot: the weekly quota resets on a new ISO week", async (t) => {
  fakeStore(t, {"usersv2/u": {}, "githubUploadStats/u": {day: "x", count: 0, week: "2000-01-03", weekCount: 3}});
  assert.equal(await reserveUploadSlot("u", true, NOW), true);
});

test("reserveUploadSlot: premium users are not limited weekly", async (t) => {
  const store = fakeStore(t, {"usersv2/u": {premium: true}});
  for (let i = 0; i < 5; i++) assert.equal(await reserveUploadSlot("u", true, NOW), false);
  assert.equal(store.get("githubUploadStats/u")?.weekCount, 0);
});

// Subscription sync

test("claimSyncSlot: blocks a second sync inside 30 seconds and allows it after", async (t) => {
  fakeStore(t, {});
  assert.equal(await claimSyncSlot("u", NOW), true);
  assert.equal(await claimSyncSlot("u", NOW + 29_999), false);
  assert.equal(await claimSyncSlot("u", NOW + 30_000), true);
});

test("syncSubscription: inside the cooldown returns the stored tier without calling RevenueCat", async (t) => {
  fakeStore(t, {"subscriptionSync/u": {lastAt: Date.now()}});
  t.mock.method(db, "collection", (name: string) => ({
    doc: () => name === "subscriptionSync" ?
      {path: "subscriptionSync/u"} :
      {get: async () => ({data: () => ({premium: true, subscriptionTier: "pro"})})},
  }));
  t.mock.method(globalThis, "fetch", () => {
    throw new Error("must not call RevenueCat");
  });
  assert.deepEqual(await run(syncSubscription, {auth: {uid: "u"}, data: {}}), {premium: true, subscriptionTier: "pro"});
});
