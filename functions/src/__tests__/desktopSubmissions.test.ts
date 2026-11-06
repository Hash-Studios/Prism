import assert from "node:assert/strict";
import * as admin from "firebase-admin";
import test, {type TestContext} from "node:test";
import sharp from "sharp";
import {createHash} from "node:crypto";
import {
  checkDesktopImage, DESKTOP_UPLOAD_LEASE_MS, removeDesktopSubmissionsForAccount, removeDesktopSubmissionsForWall,
  renderCreatorDesktop, reviewDesktopSubmission, submitDesktopVersion,
} from "../desktopSubmissions";
import {R2Storage} from "../r2Storage";
import {parseDesktopVariant, readyDesktopCompanion, removeDesktopCompanion} from "../studio/desktop";
import {type Doc, installFakeDb} from "./fakeDb";

type Row = Record<string, any>;
const PREVIEW = "https://images.example.com";
const maker = {uid: "maker", token: {email: "maker@example.com", email_verified: true}};
const stranger = {uid: "other", token: {email: "other@example.com", email_verified: true}};
const moderator = {uid: "moderator", token: {admin: true}};

const png = async (width: number, height: number, background = "navy") =>
  (await sharp({create: {width, height, channels: 3, background}}).png().toBuffer()).toString("base64");

function setup(t: TestContext, docs: Record<string, Doc> = {}, opts: {
  failPutAt?: number; onPut?: (put: number, store: Map<string, Row>) => Promise<void>;
} = {}) {
  const env = {...process.env};
  t.after(() => {
    process.env = env;
  });
  Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access",
    R2_SECRET_ACCESS_KEY: "secret", R2_PRIVATE_BUCKET: "private", R2_PREVIEW_BUCKET: "preview",
    R2_PREVIEW_BASE_URL: PREVIEW});
  const store = installFakeDb(t, {
    "usersv2/maker": {email: "maker@example.com"},
    "usersv2/other": {email: "other@example.com"},
    "walls/w1": {id: "WALL1", creatorUid: "maker", email: "maker@example.com", review: true, title: "Dunes", by: "Maker",
      wallpaper_thumb: "https://img.example.com/thumb.jpg"},
    ...docs,
  }) as Map<string, Row>;
  const objects = new Set<string>();
  const removed: string[] = [];
  let puts = 0;
  t.mock.method(R2Storage.prototype, "put", async (_kind: string, object: string) => {
    if (++puts === opts.failPutAt) throw new Error("R2 PUT failed (500)");
    objects.add(object);
    await opts.onPut?.(puts, store);
    return true;
  });
  t.mock.method(R2Storage.prototype, "head", async () => null);
  t.mock.method(R2Storage.prototype, "delete", async (_kind: string, object: string) => {
    removed.push(object);
    objects.delete(object);
  });
  t.mock.method(admin.messaging(), "send", async () => "message-id");
  return {store, objects, removed};
}

type Auth = typeof maker | typeof stranger | typeof moderator;
const submit = async (auth: Auth, contentBase64: string, wallDocId = "w1") =>
  (await submitDesktopVersion.run({auth, data: {wallDocId, contentBase64}} as never)) as {submissionId: string; state: string};
const review = (data: Record<string, unknown>, auth: Auth = moderator) =>
  reviewDesktopSubmission.run({auth, data} as never) as Promise<{state: string}>;
const refusedWith = (code: string, message: string) => (error: unknown) => {
  assert.equal((error as {code?: string}).code, code);
  assert.equal((error as Error).message, message);
  return true;
};
const submissionObjects = (doc: Row | undefined) =>
  [doc?.original?.object, doc?.wide?.object, doc?.thumb?.object] as string[];
const creatorVersion = (doc: Row | undefined) =>
  createHash("sha256").update(`${doc?.original.sha256}\0${doc?.wide.sha256}`).digest("hex").slice(0, 16);
const inbox = (store: Map<string, Row>) => [...store.entries()].filter(([path]) => path.startsWith("notifications/"))
  .map(([, doc]) => doc);

test("checkDesktopImage accepts 16:10 and 16:9 within 2% and names each problem in order", () => {
  assert.deepEqual(checkDesktopImage(2560, 1600), {aspect: "16:10"});
  assert.deepEqual(checkDesktopImage(1920, 1080), {aspect: "16:9"});
  assert.deepEqual(checkDesktopImage(1920, 1188), {aspect: "16:10"});
  assert.deepEqual(checkDesktopImage(1080, 1920), {problem: "desktop-not-landscape"});
  assert.deepEqual(checkDesktopImage(1500, 1500), {problem: "desktop-not-landscape"});
  assert.deepEqual(checkDesktopImage(0, 0), {problem: "desktop-not-landscape"});
  assert.deepEqual(checkDesktopImage(2400, 1800), {problem: "desktop-aspect-ratio"});
  assert.deepEqual(checkDesktopImage(1920, 1260), {problem: "desktop-aspect-ratio"});
  assert.deepEqual(checkDesktopImage(1600, 1000), {problem: "desktop-too-small"});
  assert.deepEqual(checkDesktopImage(1919, 1200), {problem: "desktop-too-small"});
});

test("renderCreatorDesktop makes the Studio companion sizes from a 1920 px upload and keeps a 16:9 upload's full width", async () => {
  const out = await renderCreatorDesktop(Buffer.from(await png(1920, 1080), "base64"));
  const size = async (bytes: Buffer) => {
    const meta = await sharp(bytes).metadata();
    return [meta.format, meta.width, meta.height];
  };
  assert.deepEqual(await size(out.original), ["jpeg", 2560, 1600]);
  assert.deepEqual(await size(out.wide), ["jpeg", 2560, 1440]);
  assert.deepEqual(await size(out.thumb), ["jpeg", 960, 600]);
  assert.deepEqual([out.width, out.height, out.aspect], [1920, 1080, "16:9"]);
});

test("renderCreatorDesktop reads the upright size from the EXIF orientation", async () => {
  const sideways = await sharp({create: {width: 1200, height: 1920, channels: 3, background: "teal"}})
    .jpeg().withMetadata({orientation: 6}).toBuffer();
  const out = await renderCreatorDesktop(sideways);
  assert.deepEqual([out.width, out.height, out.aspect], [1920, 1200, "16:10"]);
});

test("a creator cannot submit a desktop version for another creator's wall", async (t) => {
  const {objects, store} = setup(t);
  await assert.rejects(submit(stranger, await png(2560, 1600)), refusedWith("permission-denied", "desktop-not-owner"));
  assert.equal(objects.size, 0);
  assert.equal([...store.keys()].some((path) => path.startsWith("desktopSubmissions/")), false);
});

test("creatorUid wins over conflicting wall, token and profile emails", async (t) => {
  const {store} = setup(t, {"walls/w1": {id: "WALL1", creatorUid: "maker", email: "other@example.com", review: true}});
  const lookup = t.mock.method(admin.auth(), "getUserByEmail", async () => {
    throw new Error("A creatorUid wall must not resolve ownership by email.");
  });
  await assert.rejects(submit(stranger, await png(2560, 1600)), refusedWith("permission-denied", "desktop-not-owner"));
  const {submissionId} = await submit({...maker, token: {...maker.token, email: "different@example.com"}},
    await png(2560, 1600));
  await review({submissionId, decision: "approve"});
  assert.equal(store.get(`desktopSubmissions/${submissionId}`)?.creatorUid, "maker");
  assert.equal(lookup.mock.callCount(), 0);
});

test("a legacy wall requires server-verified email ownership, not a matching token or profile", async (t) => {
  setup(t, {"walls/w1": {id: "WALL1", email: "maker@example.com", review: true},
    "usersv2/other": {email: "maker@example.com"}});
  let verified = false;
  t.mock.method(admin.auth(), "getUserByEmail", async () => ({uid: "maker", emailVerified: verified}));
  const image = await png(2560, 1600);
  await assert.rejects(submit(maker, image), refusedWith("permission-denied", "desktop-not-owner"));
  verified = true;
  await assert.rejects(submit({...stranger, token: {...stranger.token, email: "maker@example.com"}}, image),
    refusedWith("permission-denied", "desktop-not-owner"));
  const {submissionId} = await submit(maker, image);
  verified = false;
  await assert.rejects(review({submissionId, decision: "approve"}),
    refusedWith("failed-precondition", "desktop-wall-unavailable"));
  verified = true;
  await review({submissionId, decision: "approve"});
});

test("an explicit unavailable creatorUid never falls back to a matching verified email", async (t) => {
  setup(t, {"walls/w1": {id: "WALL1", creatorUid: "", email: "maker@example.com", review: true}});
  const lookup = t.mock.method(admin.auth(), "getUserByEmail", async () => ({uid: "maker", emailVerified: true}));
  await assert.rejects(submit(maker, await png(2560, 1600)), refusedWith("permission-denied", "desktop-not-owner"));
  assert.equal(lookup.mock.callCount(), 0);
});

test("a creator cannot submit a desktop version for an unapproved wall", async (t) => {
  setup(t, {"walls/w2": {id: "WALL2", creatorUid: "maker", review: false}});
  await assert.rejects(submit(maker, await png(2560, 1600), "w2"),
    refusedWith("failed-precondition", "desktop-wall-not-approved"));
});

test("the server refuses a portrait image, a bad aspect ratio and a small image, whatever the app checked", async (t) => {
  const {objects} = setup(t);
  await assert.rejects(submit(maker, await png(1200, 1920)), refusedWith("invalid-argument", "desktop-not-landscape"));
  await assert.rejects(submit(maker, await png(2400, 1800)), refusedWith("invalid-argument", "desktop-aspect-ratio"));
  await assert.rejects(submit(maker, await png(1600, 1000)), refusedWith("invalid-argument", "desktop-too-small"));
  await assert.rejects(submit(maker, Buffer.from("not an image").toString("base64")),
    refusedWith("invalid-argument", "desktop-image-invalid"));
  assert.equal(objects.size, 0);
});

test("a submission stores its files, waits as pending and does not touch the wall", async (t) => {
  const {store, objects} = setup(t);
  const {submissionId, state} = await submit(maker, await png(2560, 1600));
  assert.equal(state, "pending");
  const doc = store.get(`desktopSubmissions/${submissionId}`);
  assert.equal(doc?.state, "pending");
  assert.equal(doc?.creatorUid, "maker");
  assert.equal(doc?.shareId, "WALL1");
  assert.deepEqual(doc?.source, {width: 2560, height: 1600, aspect: "16:10"});
  assert.equal(doc?.wallThumb, "https://img.example.com/thumb.jpg");
  assert.equal(doc?.replaces, false);
  assert.equal(doc?.leaseUntil, undefined);
  assert.deepEqual([...objects].sort(), submissionObjects(doc).sort());
  assert.ok(doc?.original.object.startsWith("desktop-originals/WALL1/"));
  assert.ok(doc?.thumb.url.startsWith(`${PREVIEW}/previews/desktop-`));
  assert.equal(store.get("walls/w1")?.desktopVariant, undefined);
  assert.equal(store.get("desktopCompanions/WALL1"), undefined);
});

test("a second submission for the same wall is refused while one is pending", async (t) => {
  setup(t);
  await submit(maker, await png(2560, 1600));
  await assert.rejects(submit(maker, await png(1920, 1080, "maroon")),
    refusedWith("failed-precondition", "desktop-pending-exists"));
});

test("a crashed upload past its lease gives way to a new submission and its files are deleted", async (t) => {
  const stale = {wallDocId: "w1", shareId: "WALL1", creatorUid: "maker", state: "uploading",
    original: {object: `desktop-originals/WALL1/${"a".repeat(64)}.jpg`},
    wide: {object: `desktop-originals/WALL1/${"b".repeat(64)}.jpg`},
    thumb: {object: `previews/desktop-${"c".repeat(64)}.jpg`},
    leaseUntil: admin.firestore.Timestamp.fromMillis(Date.now() - DESKTOP_UPLOAD_LEASE_MS)};
  const {store, removed} = setup(t, {"desktopSubmissions/stale": stale});
  await submit(maker, await png(2560, 1600));
  assert.equal(store.get("desktopSubmissions/stale"), undefined);
  assert.deepEqual(removed.sort(), submissionObjects(stale).sort());
});

test("a failed upload deletes the files it stored and the submission", async (t) => {
  const {store, objects} = setup(t, {}, {failPutAt: 3});
  await assert.rejects(submit(maker, await png(2560, 1600)), refusedWith("unavailable", "desktop-store-failed"));
  assert.equal(objects.size, 0);
  assert.equal([...store.keys()].some((path) => path.startsWith("desktopSubmissions/")), false);
  await submit(maker, await png(2560, 1600));
});

test("a wall deleted during upload cannot leave a pending submission or stored files", async (t) => {
  const {store, objects} = setup(t, {}, {onPut: async (put, docs) => {
    if (put === 1) docs.delete("walls/w1");
  }});
  await assert.rejects(submit(maker, await png(2560, 1600)),
    refusedWith("not-found", "desktop-wall-not-found"));
  assert.equal(objects.size, 0);
  assert.equal([...store.keys()].some((path) => path.startsWith("desktopSubmissions/")), false);
});

test("a submission removed during storage still cleans files written after removal", async (t) => {
  const {store, objects} = setup(t, {}, {onPut: async (put, docs) => {
    if (put === 1) {
      docs.set("creatorDeletionState/maker", {closed: true});
      for (const path of docs.keys()) if (path.startsWith("desktopSubmissions/")) docs.delete(path);
    }
  }});
  await assert.rejects(submit(maker, await png(2560, 1600)),
    refusedWith("aborted", "desktop-upload-withdrawn"));
  assert.equal(objects.size, 0);
  assert.equal([...store.keys()].some((path) => path.startsWith("desktopSubmissions/")), false);
});

test("a withdrawn crash record is cleaned on the next submission", async (t) => {
  const orphan = {wallDocId: "w1", shareId: "WALL1", creatorUid: "maker", state: "withdrawn",
    original: {object: `desktop-originals/WALL1/${"a".repeat(64)}.jpg`},
    wide: {object: `desktop-originals/WALL1/${"b".repeat(64)}.jpg`},
    thumb: {object: `previews/desktop-${"c".repeat(64)}.jpg`}};
  const {store, removed} = setup(t, {"desktopSubmissions/orphan": orphan});
  await submit(maker, await png(2560, 1600));
  assert.equal(store.get("desktopSubmissions/orphan"), undefined);
  assert.deepEqual(removed.sort(), submissionObjects(orphan).sort());
});

test("a stale cleanup error does not strand the new submission as uploading", async (t) => {
  const stale = {wallDocId: "w1", shareId: "WALL1", creatorUid: "maker", state: "uploading",
    original: {object: `desktop-originals/WALL1/${"a".repeat(64)}.jpg`},
    leaseUntil: admin.firestore.Timestamp.fromMillis(0)};
  const {store} = setup(t, {"desktopSubmissions/stale": stale});
  let first = true;
  t.mock.method(R2Storage.prototype, "delete", async () => {
    if (first) {
      first = false;
      throw new Error("R2 DELETE failed (500)");
    }
  });
  await assert.rejects(submit(maker, await png(2560, 1600)),
    refusedWith("unavailable", "desktop-store-failed"));
  assert.equal([...store.values()].some((doc) => doc.state === "uploading"), false);
  await submit(maker, await png(2560, 1600));
  assert.equal(store.get("desktopSubmissions/stale"), undefined);
});

test("only an admin can review, and a reject needs a reason", async (t) => {
  setup(t);
  const {submissionId} = await submit(maker, await png(2560, 1600));
  await assert.rejects(review({submissionId, decision: "approve"}, maker),
    refusedWith("permission-denied", "Only admins can review desktop versions."));
  await assert.rejects(review({submissionId, decision: "reject", reason: "  "}),
    refusedWith("invalid-argument", "A reason is required."));
  await assert.rejects(review({submissionId, decision: "reject", reason: "Blurry", reasonCode: "made-up"}),
    refusedWith("invalid-argument", "Invalid reasonCode."));
});

test("approve links the desktop version to the wall with a new v and tells the creator", async (t) => {
  const {store} = setup(t);
  const {submissionId} = await submit(maker, await png(2560, 1600));
  assert.deepEqual(await review({submissionId, decision: "approve"}), {state: "approved"});

  const submission = store.get(`desktopSubmissions/${submissionId}`);
  const variant = parseDesktopVariant(store.get("walls/w1")?.desktopVariant);
  assert.ok(variant);
  assert.equal(variant.v, creatorVersion(submission));
  assert.equal(variant.thumb, submission?.thumb.url);
  assert.equal(submission?.state, "approved");
  assert.equal(submission?.decidedBy, "moderator");
  const companion = await readyDesktopCompanion("WALL1", store.get("walls/w1"));
  assert.equal(companion.original.object, submission?.original.object);
  assert.equal(store.get("desktopCompanions/WALL1")?.source, "creator");

  const [notice] = inbox(store);
  assert.equal(notice?.message.kind, "desktopVersionApproved");
  assert.equal(notice?.notification.title, "Your desktop version is live");
  assert.equal(notice?.notification.body, "\"Dunes\" now has a desktop version.");
  assert.equal(notice?.modifier, "maker@example.com");
  assert.equal(notice?.data.notification_kind, "desktop_version_approved");

  assert.deepEqual(await review({submissionId, decision: "approve"}), {state: "approved"});
  assert.equal(inbox(store).length, 1);
  await assert.rejects(review({submissionId, decision: "reject", reason: "Too late"}),
    refusedWith("failed-precondition", "desktop-not-pending"));
});

test("approve is refused when the wall is no longer approved", async (t) => {
  const {store} = setup(t);
  const {submissionId} = await submit(maker, await png(2560, 1600));
  store.set("walls/w1", {...store.get("walls/w1"), review: false});
  await assert.rejects(review({submissionId, decision: "approve"}),
    refusedWith("failed-precondition", "desktop-wall-unavailable"));
  assert.equal(store.get(`desktopSubmissions/${submissionId}`)?.state, "pending");
  assert.equal(store.get("walls/w1")?.desktopVariant, undefined);
});

test("reject keeps the live desktop version, deletes the new files and tells the creator the reason", async (t) => {
  const {store, removed, objects} = setup(t);
  const first = await submit(maker, await png(2560, 1600));
  await review({submissionId: first.submissionId, decision: "approve"});
  const live = store.get("walls/w1")?.desktopVariant;
  const liveFiles = submissionObjects(store.get(`desktopSubmissions/${first.submissionId}`));

  const second = await submit(maker, await png(1920, 1080, "maroon"));
  assert.equal(store.get(`desktopSubmissions/${second.submissionId}`)?.replaces, true);
  assert.deepEqual(await review({submissionId: second.submissionId, decision: "reject", reason: "It is blurry.",
    reasonCode: "blurry"}), {state: "rejected"});

  const rejected = store.get(`desktopSubmissions/${second.submissionId}`);
  assert.equal(rejected?.state, "rejected");
  assert.equal(rejected?.reason, "It is blurry.");
  assert.equal(rejected?.reasonCode, "blurry");
  assert.equal(rejected?.filesDeleted, true);
  assert.deepEqual(store.get("walls/w1")?.desktopVariant, live);
  assert.deepEqual(removed.sort(), submissionObjects(rejected).sort());
  assert.deepEqual([...objects].sort(), [...liveFiles].sort());
  const notice = inbox(store).find((doc) => doc.message.kind === "desktopVersionRejected");
  assert.equal(notice?.notification.body, "Reason: It is blurry.");
  assert.equal(notice?.data.notification_kind, "desktop_version_rejected");
});

test("rejecting an upload identical to the live desktop version keeps the live files", async (t) => {
  const {store, objects} = setup(t);
  const image = await png(2560, 1600);
  const first = await submit(maker, image);
  await review({submissionId: first.submissionId, decision: "approve"});
  const second = await submit(maker, image);
  await review({submissionId: second.submissionId, decision: "reject", reason: "Duplicate.", reasonCode: "duplicate"});
  assert.equal(objects.size, 3);
  await readyDesktopCompanion("WALL1", store.get("walls/w1"));
});

test("a committed rejection notifies once even if object cleanup fails and is retried", async (t) => {
  const {store, objects} = setup(t);
  const {submissionId} = await submit(maker, await png(2560, 1600));
  let fail = true;
  t.mock.method(R2Storage.prototype, "delete", async (_kind: string, object: string) => {
    if (fail) throw new Error("R2 DELETE failed (500)");
    objects.delete(object);
  });
  await assert.rejects(review({submissionId, decision: "reject", reason: "Blurry."}));
  assert.equal(store.get(`desktopSubmissions/${submissionId}`)?.state, "rejected");
  assert.equal(inbox(store).length, 1);
  fail = false;
  await review({submissionId, decision: "reject", reason: "Changed retry reason."});
  assert.equal(objects.size, 0);
  assert.equal(inbox(store).length, 1);
  assert.equal(inbox(store)[0].notification.body, "Reason: Blurry.");
});

test("a committed approval notifies once before retired-file cleanup and retries only that cleanup", async (t) => {
  const {store, objects} = setup(t);
  const first = await submit(maker, await png(2560, 1600));
  await review({submissionId: first.submissionId, decision: "approve"});
  const second = await submit(maker, await png(1920, 1080, "maroon"));
  let fail = true;
  t.mock.method(R2Storage.prototype, "delete", async (_kind: string, object: string) => {
    if (fail) throw new Error("R2 DELETE failed (500)");
    objects.delete(object);
  });
  await assert.rejects(review({submissionId: second.submissionId, decision: "approve"}));
  assert.equal(store.get(`desktopSubmissions/${second.submissionId}`)?.state, "approved");
  assert.equal(inbox(store).length, 2);
  fail = false;
  await review({submissionId: second.submissionId, decision: "approve"});
  assert.equal(objects.size, 3);
  assert.equal(inbox(store).length, 2);
  assert.equal(store.get("desktopCompanions/WALL1")?.pendingObjects, undefined);
});

test("retrying rejection cannot delete the files reused by a new pending submission", async (t) => {
  const {store, objects} = setup(t);
  const image = await png(2560, 1600);
  const first = await submit(maker, image);
  let fail = true;
  t.mock.method(R2Storage.prototype, "delete", async (_kind: string, object: string) => {
    if (fail) throw new Error("R2 DELETE failed (500)");
    objects.delete(object);
  });
  await assert.rejects(review({submissionId: first.submissionId, decision: "reject", reason: "Blurry."}));
  fail = false;
  const second = await submit(maker, image);
  await review({submissionId: first.submissionId, decision: "reject", reason: "Blurry."});
  assert.equal(objects.size, 3);
  await review({submissionId: second.submissionId, decision: "approve"});
  await readyDesktopCompanion("WALL1", store.get("walls/w1"));
});

test("a new upload cannot reuse content-addressed files while rejection is deleting them", async (t) => {
  const {objects} = setup(t);
  const image = await png(2560, 1600);
  const {submissionId} = await submit(maker, image);
  let probed = false;
  t.mock.method(R2Storage.prototype, "delete", async (_kind: string, object: string) => {
    if (!probed) {
      probed = true;
      await assert.rejects(submit(maker, image), refusedWith("unavailable", "desktop-storage-busy"));
    }
    objects.delete(object);
  });
  await review({submissionId, decision: "reject", reason: "Blurry."});
  assert.equal(probed, true);
  assert.equal(objects.size, 0);
});

test("rejecting a creator upload preserves the files still journaled by a queued Studio companion", async (t) => {
  const {store, objects} = setup(t);
  const {submissionId} = await submit(maker, await png(2560, 1600));
  const files = submissionObjects(store.get(`desktopSubmissions/${submissionId}`));
  store.set("desktopCompanions/WALL1", {status: "queued", pendingObjects: files.map((object, index) => ({
    kind: index < 2 ? "private" : "preview", object,
  }))});
  await review({submissionId, decision: "reject", reason: "Blurry."});
  assert.deepEqual([...objects].sort(), files.sort());
});

test("changing only the wide image changes the desktop cache version", async (t) => {
  const {store} = setup(t);
  const image = async (edge: string) => (await sharp({create: {
    width: 2560, height: 1440, channels: 3, background: edge,
  }}).composite([{input: await sharp({create: {width: 2400, height: 1440, channels: 3, background: "navy"}})
    .png().toBuffer(), left: 80, top: 0}]).png().toBuffer()).toString("base64");
  const first = await submit(maker, await image("red"));
  await review({submissionId: first.submissionId, decision: "approve"});
  const firstDoc = store.get(`desktopSubmissions/${first.submissionId}`);
  const oldVersion = store.get("walls/w1")?.desktopVariant.v;
  const second = await submit(maker, await image("green"));
  await review({submissionId: second.submissionId, decision: "approve"});
  const secondDoc = store.get(`desktopSubmissions/${second.submissionId}`);
  assert.equal(firstDoc?.original.sha256, secondDoc?.original.sha256);
  assert.notEqual(firstDoc?.wide.sha256, secondDoc?.wide.sha256);
  assert.notEqual(oldVersion, store.get("walls/w1")?.desktopVariant.v);
  await readyDesktopCompanion("WALL1", store.get("walls/w1"));
});

test("approval refuses a wall whose creator changed while the upload waited", async (t) => {
  const {store} = setup(t);
  const {submissionId} = await submit(maker, await png(2560, 1600));
  store.set("walls/w1", {...store.get("walls/w1"), creatorUid: "other"});
  await assert.rejects(review({submissionId, decision: "approve"}),
    refusedWith("failed-precondition", "desktop-wall-unavailable"));
  assert.equal(store.get(`desktopSubmissions/${submissionId}`)?.state, "pending");
});

test("replace approves a new desktop version, changes v and deletes the old files", async (t) => {
  const {store, removed, objects} = setup(t);
  const first = await submit(maker, await png(2560, 1600));
  await review({submissionId: first.submissionId, decision: "approve"});
  const oldV = store.get("walls/w1")?.desktopVariant.v;
  const oldFiles = submissionObjects(store.get(`desktopSubmissions/${first.submissionId}`));

  const second = await submit(maker, await png(1920, 1080, "maroon"));
  await review({submissionId: second.submissionId, decision: "approve"});
  const newFiles = submissionObjects(store.get(`desktopSubmissions/${second.submissionId}`));
  const newV = store.get("walls/w1")?.desktopVariant.v;
  assert.notEqual(newV, oldV);
  assert.equal(newV, creatorVersion(store.get(`desktopSubmissions/${second.submissionId}`)));
  assert.deepEqual(removed.sort(), [...oldFiles].sort());
  assert.deepEqual([...objects].sort(), [...newFiles].sort());
  assert.equal(store.get("desktopCompanions/WALL1")?.pendingObjects, undefined);
  assert.equal(store.get("desktopCompanions/WALL1")?.submissionId, second.submissionId);
});

test("deleting the wall deletes the live companion, the pending upload and every submission", async (t) => {
  const {store, objects} = setup(t);
  const first = await submit(maker, await png(2560, 1600));
  await review({submissionId: first.submissionId, decision: "approve"});
  await submit(maker, await png(1920, 1080, "maroon"));
  assert.equal(objects.size, 6);

  store.delete("walls/w1");
  await removeDesktopCompanion("WALL1", {worker: {base: "https://worker.example.com", secret: "s"}});
  await removeDesktopSubmissionsForWall("w1");
  assert.equal(objects.size, 0);
  assert.equal(store.get("desktopCompanions/WALL1"), undefined);
  assert.equal([...store.keys()].some((path) => path.startsWith("desktopSubmissions/")), false);
});

test("account deletion deletes the pending upload and keeps the approved desktop version on the wall", async (t) => {
  const {store, objects} = setup(t);
  const first = await submit(maker, await png(2560, 1600));
  await review({submissionId: first.submissionId, decision: "approve"});
  const liveFiles = submissionObjects(store.get(`desktopSubmissions/${first.submissionId}`));
  await submit(maker, await png(1920, 1080, "maroon"));

  await removeDesktopSubmissionsForAccount("maker");
  assert.deepEqual([...objects].sort(), [...liveFiles].sort());
  assert.equal([...store.keys()].some((path) => path.startsWith("desktopSubmissions/")), false);
  await readyDesktopCompanion("WALL1", store.get("walls/w1"));
});

test("account deletion drains an approved replacement's crash cleanup before deleting its receipt", async (t) => {
  const {store, objects, removed} = setup(t);
  const first = await submit(maker, await png(2560, 1600));
  await review({submissionId: first.submissionId, decision: "approve"});
  const orphan = `desktop-originals/WALL1/${"a".repeat(64)}.jpg`;
  objects.add(orphan);
  store.set("desktopCompanions/WALL1", {...store.get("desktopCompanions/WALL1"),
    pendingObjects: [{kind: "private", object: orphan}]});
  await removeDesktopSubmissionsForAccount("maker");
  assert.ok(removed.includes(orphan));
  assert.equal(objects.size, 3);
  assert.equal(store.get("desktopCompanions/WALL1")?.pendingObjects, undefined);
  assert.equal(store.get(`desktopSubmissions/${first.submissionId}`), undefined);
  await readyDesktopCompanion("WALL1", store.get("walls/w1"));
});
