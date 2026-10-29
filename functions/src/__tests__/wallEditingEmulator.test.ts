import assert from "node:assert/strict";
import {createHash, randomUUID} from "node:crypto";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db, utcDateString} from "../common";
import {githubPutFile} from "../githubContent";
import {R2Storage} from "../r2Storage";
import {uploadFileKey, uploadPathKey, type FileReference} from "../completedWallUpload";
import {digest, revisionOf} from "../wallEditingCommon";
import {editWallMetadata, getWallMetadataForEdit, listWallMetadataEdits, revertWallMetadata} from "../wallMetadata";
import {getWallResubmissionContext, rejectWallForReview, sanitizeResubmitOf, submitWallResubmission, undoWallRejection} from "../wallResubmissions";
import {sanitizeSubmissionText} from "../wallSubmissionSafety";
import {onWallSearchTerms, wallSearchTermsFor} from "../wallSearchTerms";
import {bindOwnedWall, cleanupDeletedOwnedWall, getOwnedWallDelivery} from "../ownedAssetDelivery";

const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
const gate = {skip: !enabled, timeout: 120000};
const metadata = {title: "Quiet forest", desc: "Blue light", tags: ["nature"]};
const hashBlob = (bytes: Buffer) => createHash("sha1").update(`blob ${bytes.length}\0`).update(bytes).digest("hex");

async function fixture(t: TestContext, kind: "github" | "owned" = "github") {
  assert.equal(admin.app().options.projectId ?? process.env.GCLOUD_PROJECT, "demo-prism");
  const uid = `d22_${randomUUID().replace(/-/g, "")}`;
  const email = `${uid}@example.com`;
  const auth = {uid, token: {}};
  const adminAuth = {uid: `${uid}_admin`, token: {admin: true}};
  const envKeys = ["GH_USERNAME", "GH_REPO_WALLS", "GH_REPO_SETUPS", "GH_TOKEN", "R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY", "R2_PRIVATE_BUCKET", "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"];
  const oldEnv = Object.fromEntries(envKeys.map((key) => [key, process.env[key]]));
  envKeys.forEach((key) => delete process.env[key]);
  Object.assign(process.env, {GH_USERNAME: "owner", GH_REPO_WALLS: "walls", GH_REPO_SETUPS: "setups", GH_TOKEN: "test"});
  if (kind === "owned") {
    Object.assign(process.env, {R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "test",
      R2_SECRET_ACCESS_KEY: "test", R2_PRIVATE_BUCKET: "originals", R2_PREVIEW_BUCKET: "previews",
      R2_PREVIEW_BASE_URL: "https://images.example.com"});
  }
  const refs = new Set<string>();
  const ref = (path: string) => {
    refs.add(path); return db.doc(path);
  };
  await ref(`usersv2/${uid}`).set({name: "Maker", profilePhoto: "photo", premium: true, email});
  await ref(`usersv2/${adminAuth.uid}`).set({name: "Admin"});
  const sourceId = `wall_${uid}_1700000000000_${"old.".repeat(25)}jpg`;
  const sourceRef = ref(`rejectedWalls/${sourceId}`);
  await sourceRef.set({id: `old_${uid}`, creatorUid: uid, email, review: false,
    wallpaper_url: "old", wallpaper_thumb: "old-thumb", wallpaper_path: "old.jpg", thumb_path: "thumb_old.jpg",
    rejectionReason: "Please improve the crop", ...metadata});
  const github = new Map<string, {bytes: Buffer; sha: string}>();
  t.mock.method(globalThis, "fetch", async (url: string | URL | Request, init?: RequestInit) => {
    const path = decodeURIComponent(String(url).split("/contents/")[1] ?? "");
    assert.ok(path, `unexpected network request ${String(url)}`);
    if (init?.method === "PUT") {
      const body = JSON.parse(String(init.body));
      const bytes = Buffer.from(body.content, "base64");
      github.set(path, {bytes, sha: hashBlob(bytes)});
    }
    const value = github.get(path);
    return new Response(JSON.stringify(value ? {path, sha: value.sha, type: "file",
      download_url: `https://raw.githubusercontent.com/owner/walls/main/${encodeURIComponent(path)}`,
      ...(init?.method === "PUT" ? {content: {path, sha: value.sha,
        download_url: `https://raw.githubusercontent.com/owner/walls/main/${encodeURIComponent(path)}`}} : {})} : {}),
    {status: value ? 200 : 404});
  });
  const objects = new Map<string, {bytes: Buffer; metadata: Record<string, string>}>();
  t.mock.method(R2Storage.prototype, "put", async (bucket: string, name: string, bytes: Buffer, fields: Record<string, string>) => {
    objects.set(`${bucket}/${name}`, {bytes, metadata: fields}); return true;
  });
  t.mock.method(R2Storage.prototype, "head", async (bucket: string, name: string) => {
    const object = objects.get(`${bucket}/${name}`);
    if (!object) return null;
    const m = object.metadata;
    return {size: object.bytes.length, contentType: "image/jpeg", sha256: m.sha256 ?? "", uid: m.uid ?? "",
      objectId: m.objectid ?? "", repo: Buffer.from(m.repo64 ?? "", "base64url").toString(),
      path: Buffer.from(m.path64 ?? "", "base64url").toString(), gitSha: m.gitsha ?? "", uploadId: m.uploadid ?? ""};
  });
  t.mock.method(R2Storage.prototype, "get", async (bucket: string, name: string) => {
    const object = objects.get(`${bucket}/${name}`);
    if (!object) throw new Error("missing storage object");
    return object.bytes;
  });
  let seq = 0;
  const upload = async (parent = sourceId) => {
    const basename = `${uid}_${Date.now()}_${++seq}.photo.jpg`;
    const file = async (path: string): Promise<FileReference> => {
      const bytes = Buffer.concat([Buffer.from([255, 216, 255]), Buffer.from(`${seq}_${path}`)]);
      const result = await githubPutFile.run({auth, data: {repo: "walls", path, purpose: "wallpaper", message: path,
        contentBase64: bytes.toString("base64")}} as never);
      const content = (result as unknown as {content: {path: string; sha: string}}).content;
      return {path: content.path, sha: content.sha, sourceKind: kind};
    };
    const original = await file(basename);
    const thumbnail = await file(`thumb_${basename}`);
    return {operationId: `submit_${seq}`, sourceRejectedDocId: parent, original, thumbnail,
      metadata: {...metadata, category: "Nature"}, presentation: {resolution: "1080x1920", size: "1 MB"}};
  };
  const submit = (data: unknown) => submitWallResubmission.run({auth, data} as never);
  const context = (ids: string[]) => getWallResubmissionContext.run({auth: adminAuth, data: {wallDocIds: ids}} as never);
  const reject = async (id: string) => db.runTransaction(async (tx) => {
    const wallRef = ref(`walls/${id}`);
    const wall = await tx.get(wallRef);
    tx.set(ref(`rejectedWalls/${id}`), {...wall.data(), rejectionReason: "Another crop", sourceWallCreateTime: wall.createTime});
    tx.delete(wallRef);
  });
  t.after(async () => {
    for (const [key, value] of Object.entries(oldEnv)) {
      if (value === undefined) delete process.env[key]; else process.env[key] = value;
    }
    for (const [collection, field] of [
      ["walls", "creatorUid"], ["rejectedWalls", "creatorUid"], ["githubUploads", "uid"], ["githubUploadIntents", "uid"],
      ["r2ObjectRegistry", "uid"], ["wallMetadataEditRates", "uid"], ["wallMetadataEdits", "ownerUid"],
      ["wallMetadataOperations", "ownerUid"], ["wallResubmissionRoots", "ownerUid"], ["wallResubmissions", "ownerUid"],
      ["wallResubmissionOperations", "ownerUid"], ["wallResubmissionConsumptions", "ownerUid"],
    ]) for (const doc of (await db.collection(collection).where(field, "==", uid).get()).docs) refs.add(doc.ref.path);
    refs.add(`githubUploadStats/${uid}`);
    for (const path of refs) await db.doc(path).delete();
  });
  return {uid, auth, adminAuth, sourceId, sourceRef, ref, upload, submit, context, reject, github, objects};
}

for (const kind of ["github", "owned"] as const) {
  test(`emulator: real ${kind} uploads admit one pair, verify context, replay after deletion`, gate, async (t) => {
    const f = await fixture(t, kind);
    const input = await f.upload();
    const beforeQuota = (await db.doc(`githubUploadStats/${f.uid}`).get()).data();
    const [first, replay] = await Promise.all([f.submit(input), f.submit(input)]);
    assert.deepEqual(first, replay);
    const wall = await f.ref(`walls/${first.wallDocId}`).get();
    const ledger = await db.doc(`wallResubmissions/${first.wallDocId}`).get();
    assert.deepEqual(ledger.updateTime, wall.createTime);
    assert.equal(wall.data()?.wallpaper_url === "", kind === "owned");
    assert.equal(wall.data()?.review, false);
    assert.equal(wall.data()?.resubmitOf, f.sourceId);
    assert.equal(wall.data()?.rejectionReason, undefined);
    assert.deepEqual((await f.context([first.wallDocId])).contexts[first.wallDocId], {
      verified: true, attempt: 1, rootDocId: f.sourceId, parentDocId: f.sourceId,
      previousReason: "Please improve the crop", rejectionRevision: null, rejectionOperationId: null,
      wallRevision: revisionOf(wall), hasAdmittedChild: false,
    });
    assert.equal(await sanitizeResubmitOf(wall), false);
    await assert.rejects(() => f.submit({...input, operationId: "reuse"}), {code: "failed-precondition"});
    await f.sourceRef.delete();
    await wall.ref.delete();
    for (const file of [input.original, input.thumbnail]) await db.collection("githubUploads").doc(uploadFileKey("walls", file)).delete();
    f.github.clear(); f.objects.clear();
    assert.deepEqual(await f.submit(input), first);
    assert.equal((await wall.ref.get()).exists, false);
    assert.deepEqual((await db.doc(`githubUploadStats/${f.uid}`).get()).data(), beforeQuota);
  });
}

test("emulator: four concurrent distinct admissions produce exactly three lifetime linked attempts", gate, async (t) => {
  const f = await fixture(t);
  const inputs: Awaited<ReturnType<typeof f.upload>>[] = [];
  for (let i = 0; i < 4; i++) inputs.push(await f.upload());
  const outcomes = await Promise.allSettled(inputs.map(f.submit));
  assert.equal(outcomes.filter((r) => r.status === "fulfilled").length, 3);
  const rejected = outcomes.find((r) => r.status === "rejected");
  assert.equal(rejected?.status === "rejected" && rejected.reason.code, "resource-exhausted");
  assert.equal((await db.collection("wallResubmissionRoots").doc(digest(f.sourceId)).get()).data()?.count, 3);
  assert.equal((await db.collection("walls").where("creatorUid", "==", f.uid).get()).size, 3);
  const archive = (await f.sourceRef.get()).data()!;
  await f.sourceRef.delete(); await f.sourceRef.set(archive);
  await assert.rejects(() => f.submit({...inputs[3], operationId: "after-history-recreation"}), {code: "resource-exhausted"});
});

test("emulator: descendant rejection uses its trusted root and exact archived incarnation", gate, async (t) => {
  const f = await fixture(t);
  const first = await f.submit(await f.upload());
  await f.reject(first.wallDocId);
  const input = await f.upload(first.wallDocId);
  const child = await f.submit(input);
  assert.equal(child.attempt, 2);
  const context = (await f.context([child.wallDocId])).contexts[child.wallDocId];
  assert.equal(context.verified, true);
  if (context.verified) {
    assert.equal(context.rootDocId, f.sourceId);
    assert.equal(context.previousReason, "Another crop");
  }
  const archive = f.ref(`rejectedWalls/${first.wallDocId}`);
  await archive.update({sourceWallCreateTime: admin.firestore.Timestamp.now()});
  await assert.rejects(() => f.submit({...input, operationId: "wrong-incarnation"}), {code: "failed-precondition"});
});

test("emulator: fresh standard uploads replace AI archive without inheriting AI, Studio or request provenance", gate, async (t) => {
  const f = await fixture(t);
  await f.sourceRef.update({isAiGenerated: true, origin: "studio", aiGenerationId: "old-generation", studioRunId: "old-run",
    studioCandidateId: "old-candidate", requestId: "old-request", remixOf: "old-remix"});
  const result = await f.submit(await f.upload());
  const wall = (await f.ref(`walls/${result.wallDocId}`).get()).data()!;
  assert.equal(wall.isAiGenerated, false);
  for (const key of ["origin", "aiGenerationId", "studioRunId", "studioCandidateId", "requestId", "remixOf"]) {
    assert.equal(key in wall, false);
  }
});

test("emulator: two distinct operations cannot consume the same completed pair concurrently", gate, async (t) => {
  const f = await fixture(t);
  const input = await f.upload();
  const outcomes = await Promise.allSettled([f.submit(input), f.submit({...input, operationId: "another-operation"})]);
  assert.equal(outcomes.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(outcomes.filter((r) => r.status === "rejected" && r.reason.code === "failed-precondition").length, 1);
  assert.equal((await db.collection("wallResubmissionRoots").doc(digest(f.sourceId)).get()).data()?.count, 1);
});

for (const mutation of ["tombstoned", "changed-bytes", "missing-preview"] as const) {
  test(`emulator: owned admission refuses ${mutation} retained assets`, gate, async (t) => {
    const f = await fixture(t, "owned");
    const input = await f.upload();
    const receipt = (await db.collection("githubUploads").doc(uploadFileKey("walls", input.original)).get()).data()!;
    const thumb = (await db.collection("githubUploads").doc(uploadFileKey("walls", input.thumbnail)).get()).data()!;
    if (mutation === "tombstoned") await db.collection("r2ObjectRegistry").doc(receipt.retainedAsset.objectId).update({status: "tombstoned"});
    if (mutation === "changed-bytes") f.objects.get(`private/${receipt.retainedAsset.object}`)!.bytes = Buffer.from("tampered bytes");
    if (mutation === "missing-preview") f.objects.delete(`preview/previews/${thumb.retainedAsset.objectId}.img`);
    await assert.rejects(() => f.submit(input), {code: "failed-precondition"});
    assert.equal((await db.collection("walls").where("creatorUid", "==", f.uid).get()).size, 0);
  });
}

test("emulator: admission refuses foreign, deleting and undone rejection sources and changed operation payloads", gate, async (t) => {
  const f = await fixture(t);
  const input = await f.upload();
  await f.sourceRef.update({creatorUid: `${f.uid}_admin`});
  await assert.rejects(() => f.submit(input), {code: "permission-denied"});
  await f.sourceRef.update({creatorUid: f.uid});
  const barrier = f.ref(`creatorDeletionState/${f.uid}`);
  await barrier.set({closed: true});
  await assert.rejects(() => f.submit(input), {code: "failed-precondition"});
  await barrier.delete();
  const live = f.ref(`walls/${f.sourceId}`);
  await live.set({creatorUid: f.uid});
  await assert.rejects(() => f.submit(input), {code: "failed-precondition"});
  await live.delete();
  await f.submit(input);
  await assert.rejects(() => f.submit({...input, metadata: {...input.metadata, title: "Changed"}}), {code: "already-exists"});
  await assert.rejects(() => f.context(Array(51).fill(f.sourceId)), {code: "invalid-argument"});
  await assert.rejects(() => getWallResubmissionContext.run({auth: f.auth, data: {wallDocIds: [f.sourceId]}} as never), {code: "permission-denied"});
});

test("emulator: undo rejects admitted children and deliberately continues a childless descendant", gate, async (t) => {
  const f = await fixture(t);
  const rootRevision = revisionOf(await f.sourceRef.get());
  const first = await f.submit(await f.upload());
  await assert.rejects(() => undoWallRejection.run({auth: f.adminAuth, data: {wallDocId: f.sourceId,
    expectedRejectionRevision: rootRevision, operationId: "undo-root"}} as never), {code: "aborted"});
  await f.reject(first.wallDocId);
  const rejection = await f.ref(`rejectedWalls/${first.wallDocId}`).get();
  const undo = {wallDocId: first.wallDocId, expectedRejectionRevision: revisionOf(rejection), operationId: "undo-child"};
  const result = await undoWallRejection.run({auth: f.adminAuth, data: undo} as never);
  assert.deepEqual(await undoWallRejection.run({auth: f.adminAuth, data: undo} as never), result);
  assert.equal((await f.context([first.wallDocId])).contexts[first.wallDocId].verified, true);
  await f.reject(first.wallDocId);
  assert.equal((await f.submit(await f.upload(first.wallDocId))).attempt, 2);
});

for (const mutation of ["missing", "foreign", "deleting", "generation", "old", "storage-missing", "role"] as const) {
  test(`emulator: admission refuses ${mutation} upload proof without creating a wall`, gate, async (t) => {
    const f = await fixture(t);
    const input = await f.upload();
    const receipt = db.collection("githubUploads").doc(uploadFileKey("walls", input.original));
    const intent = db.collection("githubUploadIntents").doc(uploadPathKey("walls", input.original));
    if (mutation === "missing") await receipt.delete();
    if (mutation === "foreign") await receipt.update({uid: "foreign"});
    if (mutation === "deleting") await intent.update({status: "deleting"});
    if (mutation === "generation") await receipt.update({generation: "replacement"});
    if (mutation === "old") await receipt.update({createdAt: admin.firestore.Timestamp.fromMillis(1)});
    if (mutation === "storage-missing") f.github.clear();
    if (mutation === "role") [input.original, input.thumbnail] = [input.thumbnail, input.original];
    await assert.rejects(() => f.submit(input), {code: mutation === "role" ? "invalid-argument" : "failed-precondition"});
    assert.equal((await db.collection("walls").where("creatorUid", "==", f.uid).get()).size, 0);
  });
}

test("emulator: context and sanitizers reject forged/recreated walls and preserve newer text", gate, async (t) => {
  const f = await fixture(t);
  const first = await f.submit(await f.upload());
  const ref = f.ref(`walls/${first.wallDocId}`);
  const original = await ref.get();
  const data = original.data()!;
  await ref.delete(); await ref.set({...data, title: "New incarnation", desc: "p0rn", resubmitOf: "forged"});
  assert.equal((await f.context([first.wallDocId])).contexts[first.wallDocId].verified, false);
  assert.equal(await sanitizeResubmitOf(original), false);
  const forged = await ref.get();
  assert.equal(await sanitizeResubmitOf(forged), true);
  assert.equal(await sanitizeSubmissionText(forged), true);
  assert.equal((await ref.get()).data()?.desc, "");
  const unsafe = await ref.get();
  await ref.update({title: "p0rn"});
  const unsafeTitle = await ref.get();
  await ref.update({title: "Now safe"});
  assert.equal(await sanitizeSubmissionText(unsafeTitle), false);
  await onWallSearchTerms.run({params: {wallId: first.wallDocId}, data: {after: original}} as never);
  assert.equal((await ref.get()).data()?.title, "Now safe");
  await onWallSearchTerms.run({params: {wallId: first.wallDocId}, data: {after: unsafe}} as never);
  const current = (await ref.get()).data()!;
  assert.deepEqual(current.searchTerms, wallSearchTermsFor(current));
  await assert.rejects(() => getWallResubmissionContext.run({auth: f.auth, data: {wallDocIds: [first.wallDocId]}} as never),
    {code: "permission-denied"});
  await assert.rejects(() => f.context(Array(51).fill(first.wallDocId)), {code: "invalid-argument"});
});

test("emulator: metadata exact diffs, presence audit, latest-only revert and replay survive deletion", gate, async (t) => {
  const f = await fixture(t);
  const ref = f.ref(`walls/${f.uid}_approved`);
  const original = {creatorUid: f.uid, review: true, title: "Old", category: "Nature", collections: ["premium"],
    coins: 999, dropWeek: "week", originalProtected: true, wallpaper_url: "", wallpaper_path: "",
    remixOf: "source", visionLabels: ["Tree"]};
  await ref.set(original);
  const get = () => getWallMetadataForEdit.run({auth: f.auth, data: {wallDocId: ref.id}} as never);
  const loaded = await get();
  const input = {wallDocId: ref.id, expectedRevision: loaded.revision, operationId: "edit", metadata};
  const result = await editWallMetadata.run({auth: f.auth, data: input} as never);
  assert.deepEqual((await ref.get()).data(), {...original, ...metadata, searchTerms: wallSearchTermsFor({...original, ...metadata})});
  assert.equal((await get()).revision, result.revision, JSON.stringify({wall: (await ref.get()).updateTime,
    operation: (await db.doc(`wallMetadataOperations/${digest(`${f.uid}\0edit`)}`).get()).data()?.committedAt}));
  const history = await listWallMetadataEdits.run({auth: f.adminAuth, data: {wallDocId: ref.id}} as never);
  assert.deepEqual(history.edits[0].before, {title: "Old"});
  assert.deepEqual(history.edits[0].after, metadata);
  assert.equal(history.edits[0].canRevert, true);
  assert.ok(!Number.isNaN(Date.parse(history.edits[0].createdAt)));
  const revert = {wallDocId: ref.id, auditId: result.auditId, expectedRevision: result.revision, operationId: "revert"};
  const reverted = await revertWallMetadata.run({auth: f.adminAuth, data: revert} as never);
  assert.deepEqual((await ref.get()).data(), {...original, searchTerms: wallSearchTermsFor(original)});
  assert.equal((await get()).revision, reverted.revision);
  await assert.rejects(() => revertWallMetadata.run({auth: f.adminAuth, data: {...revert,
    operationId: "old-selection", expectedRevision: reverted.revision}} as never), {code: "aborted"});
  await ref.delete();
  assert.deepEqual(await editWallMetadata.run({auth: f.auth, data: input} as never), result);
  assert.equal((await ref.get()).exists, false);
  assert.equal((await db.doc(`wallMetadataEditRates/${f.uid}_${utcDateString()}`).get()).data()?.count, 1);
});

test("emulator: concurrent metadata saves share ten-per-day budget while no-op and replay cost zero", gate, async (t) => {
  const f = await fixture(t);
  const inputs = [];
  for (let i = 0; i < 12; i++) {
    const ref = f.ref(`walls/${f.uid}_${i}`);
    await ref.set({creatorUid: f.uid, review: true, title: "Before", desc: "", tags: []});
    inputs.push({wallDocId: ref.id, expectedRevision: revisionOf(await ref.get()), operationId: `edit_${i}`, metadata});
  }
  const results = await Promise.allSettled(inputs.map((data) => editWallMetadata.run({auth: f.auth, data} as never)));
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 10);
  assert.equal(results.filter((r) => r.status === "rejected" && r.reason.code === "resource-exhausted").length, 2);
  const index = results.findIndex((r) => r.status === "fulfilled");
  const ref = db.collection("walls").doc(inputs[index].wallDocId);
  const noop = await editWallMetadata.run({auth: f.auth, data: {...inputs[index], operationId: "noop",
    expectedRevision: revisionOf(await ref.get())}} as never);
  assert.equal(noop.changed, false);
  await editWallMetadata.run({auth: f.auth, data: inputs[index]} as never);
  assert.equal((await db.doc(`wallMetadataEditRates/${f.uid}_${utcDateString()}`).get()).data()?.count, 10);
});

test("emulator: admin reject captures exact incarnation, refuses visible-status races and undo preserves approval", gate, async (t) => {
  const f = await fixture(t);
  const ref = f.ref(`walls/${f.uid}_moderated`);
  await ref.set({id: `logical_${f.uid}`, creatorUid: f.uid, email: `${f.uid}@example.com`, review: false, ...metadata});
  const context = (await f.context([ref.id])).contexts[ref.id];
  const input = {wallDocId: ref.id, expectedWallRevision: context.wallRevision, expectedReview: false,
    rejectionOperationId: "reject", reason: "Improve the crop"};
  await ref.update({review: true});
  const current = await ref.get();
  await assert.rejects(() => rejectWallForReview.run({auth: f.adminAuth, data: {...input,
    expectedWallRevision: revisionOf(current)}} as never), {code: "aborted"});
  const approvedRemoval = {...input, expectedReview: true, expectedWallRevision: revisionOf(current)};
  await rejectWallForReview.run({auth: f.adminAuth, data: approvedRemoval} as never);
  const archive = await f.ref(`rejectedWalls/${ref.id}`).get();
  assert.deepEqual(archive.data()?.sourceWallCreateTime, current.createTime);
  assert.equal(archive.data()?.review, true);
  assert.equal((await f.context([ref.id])).contexts[ref.id].rejectionOperationId, "reject");
  await undoWallRejection.run({auth: f.adminAuth, data: {wallDocId: ref.id, expectedRejectionRevision: revisionOf(archive),
    operationId: "undo-approved"}} as never);
  const restored = (await ref.get()).data()!;
  assert.equal(restored.review, true);
  assert.equal(restored.rejectionOperationId, undefined);
  assert.equal(restored.sourceWallCreateTime, undefined);
});

test("emulator: protected approved descendant retains verified lineage across reject and undo without resurrecting deleted assets", gate, async (t) => {
  const f = await fixture(t, "owned");
  t.mock.method(admin.auth(), "getUser", async () => ({uid: f.uid, email: `${f.uid}@example.com`, disabled: false}));
  t.mock.method(R2Storage.prototype, "delete", async () => true);
  const first = await f.submit(await f.upload());
  const ref = f.ref(`walls/${first.wallDocId}`);
  const manifestRef = f.ref(`ownedAssets/${first.logicalId}`);
  await ref.update({review: true});
  await bindOwnedWall(first.logicalId);
  const protectedWall = await ref.get();
  assert.equal(protectedWall.data()?.originalProtected, true);
  assert.equal((await f.context([ref.id])).contexts[ref.id].verified, true);
  await ref.update({originalObjectId: "forged"});
  assert.equal((await f.context([ref.id])).contexts[ref.id].verified, false);
  await ref.update({originalObjectId: protectedWall.data()?.originalObjectId});
  const rejection = {wallDocId: ref.id, expectedWallRevision: revisionOf(await ref.get()), expectedReview: true,
    rejectionOperationId: "protected-reject", reason: "Remove approved image"};
  await rejectWallForReview.run({auth: f.adminAuth, data: rejection} as never);
  const cleanup = {wallId: first.logicalId, canonicalPath: ref.path, incarnation: protectedWall.createTime!.toMillis(),
    incarnationNanos: protectedWall.createTime!.nanoseconds};
  await cleanupDeletedOwnedWall(cleanup);
  assert.equal((await manifestRef.get()).data()?.status, "deleted");
  const archive = await f.ref(`rejectedWalls/${ref.id}`).get();
  await undoWallRejection.run({auth: f.adminAuth, data: {wallDocId: ref.id,
    expectedRejectionRevision: revisionOf(archive), operationId: "protected-undo"}} as never);
  assert.equal((await ref.get()).data()?.review, true);
  assert.equal((await f.context([ref.id])).contexts[ref.id].verified, true);
  await assert.rejects(() => getOwnedWallDelivery(first.logicalId), /Owned wall unavailable/);
  await cleanupDeletedOwnedWall(cleanup);
  assert.equal((await manifestRef.get()).data()?.status, "deleted");
  await rejectWallForReview.run({auth: f.adminAuth, data: {...rejection, rejectionOperationId: "protected-reject-again",
    expectedWallRevision: revisionOf(await ref.get())}} as never);
  assert.equal((await f.submit(await f.upload(ref.id))).attempt, 2);
});
