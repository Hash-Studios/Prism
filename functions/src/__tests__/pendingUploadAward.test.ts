import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {createHash} from "node:crypto";
import {awardCoins} from "../coinsCallables";
import {ownedThumbnailUrl, type StoredUpload} from "../ownedAssetDelivery";
import {r2ObjectId} from "../r2Storage";
import {STUDIO_ACCOUNT} from "../studio/account";
import {installFakeDb, type Doc} from "./fakeDb";

const hash = (value: string) => createHash("sha256").update(value).digest("hex");
const request = {auth: {uid: "creator", token: {email: "creator@example.com"}},
  data: {action: "firstWallpaperUpload", sourceTag: "test"}} as unknown as Parameters<typeof awardCoins.run>[0];

function setup(t: TestContext, kind = "github") {
  for (const [key, value] of Object.entries({GH_USERNAME: "hash", GH_REPO_WALLS: "walls",
    R2_ACCOUNT_ID: "a".repeat(32), R2_ACCESS_KEY_ID: "access", R2_SECRET_ACCESS_KEY: "secret",
    R2_PRIVATE_BUCKET: "private-test", R2_PREVIEW_BUCKET: "preview-test",
    R2_PREVIEW_BASE_URL: "https://images.example.com"})) {
    const previous = process.env[key];
    process.env[key] = value;
    t.after(() => {
      if (previous === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = previous;
      }
    });
  }
  const store = installFakeDb(t, {
    "usersv2/creator": {coins: 9, email: "creator@example.com"},
    "walls/canonical": {id: "logical", email: "creator@example.com", review: false, wallpaper_provider: "Prism",
      originalProtected: true, wallpaper_url: "", wallpaper_path: "", wallpaper_sha: "",
      thumb_path: "", thumb_sha: "",
      wallpaper_thumb: ""},
  });
  for (const [path, sha] of [["logical.jpg", "a".repeat(40)], ["thumb_logical.jpg", "b".repeat(40)]]) {
    const privateAsset = kind === "owned";
    const namespace = privateAsset ? "owned_" : "";
    const digest = "c".repeat(64);
    const identity = {uid: "creator", repo: "walls", path, sha, ...(privateAsset ? {sourceKind: "owned" as const} : {})};
    const objectId = r2ObjectId(identity, digest);
    const retainedAsset = {...identity, objectId, bucket: "private-test",
      object: `${privateAsset ? "private-originals" : "retained"}/${objectId}`, sha256: digest,
      ...(path.startsWith("thumb_") ? {previewObjectId: objectId} : {})};
    store.set(`r2ObjectRegistry/${objectId}`, {status: "active", uploadId: "imported", ...retainedAsset,
      sourceKind: privateAsset ? "owned" : "github"});
    const manifest = store.get("ownedAssets/logical") as Doc | undefined;
    const assetName = path === "logical.jpg" ? "original" : "thumb";
    const priorManifest = manifest ?? {status: "ready", canonicalPath: "walls/canonical", incarnation: 1,
      incarnationNanos: 1000000, provenance: {kind, uid: "creator"}, originalUrl: kind === "owned" ? "" :
        "https://raw.githubusercontent.com/hash/walls/main/logical.jpg", thumbUrl: "",
      original: {}, thumb: {}};
    priorManifest[assetName] = retainedAsset;
    if (assetName === "thumb") {
      priorManifest.thumbUrl = kind === "owned" ? ownedThumbnailUrl(retainedAsset as unknown as StoredUpload) :
        "https://raw.githubusercontent.com/hash/walls/main/thumb_logical.jpg";
    }
    store.set("ownedAssets/logical", priorManifest);
    if (assetName === "original") store.set("walls/canonical", {...store.get("walls/canonical"), originalObjectId: objectId});
    else {
      store.set("walls/canonical", {...store.get("walls/canonical"),
        wallpaper_thumb: ownedThumbnailUrl(retainedAsset as unknown as StoredUpload)});
    }
    store.set(`githubUploads/${namespace}file_${hash(`walls\0${path}\0${sha}`)}`,
      {uid: "creator", repo: "walls", path, sha, retainedAsset, ...(privateAsset ? {sourceKind: "owned"} : {})});
    store.set(`githubUploadIntents/${namespace}path_${hash(`walls\0${path}`)}`, {uid: "creator", repo: "walls", path,
      ...(privateAsset ? {sourceKind: "owned", retainedAsset} : {}),
      blobSha: sha, status: "complete", response: {content: {path, sha,
        download_url: privateAsset && path === "logical.jpg" ? "" : privateAsset ? ownedThumbnailUrl(retainedAsset as unknown as StoredUpload) :
          `https://raw.githubusercontent.com/hash/walls/main/${path}`}}});
  }
  return store;
}

for (const kind of ["github", "owned"]) {
  test(`a redacted pending ${kind} upload earns first-upload coins exactly once`, async (t) => {
    const store = setup(t, kind);
    assert.equal((await awardCoins.run(request)).changed, true);
    assert.equal(store.get("usersv2/creator")?.coins, 59);
    assert.equal((await awardCoins.run(request)).changed, false);
    assert.equal(store.get("usersv2/creator")?.coins, 59);
    assert.equal([...store.keys()].filter((key) => key.startsWith("coinTransactions/")).length, 1);
  });
}

for (const failure of ["owner", "missing", "deleted", "incarnation", "nanos", "objectId", "path", "duplicate", "studio",
  "receipt", "intent", "legacy-provenance"]) {
  for (const reviewed of [false, true]) {
    test(`protected upload award fails closed: ${failure}, reviewed=${reviewed}`, async (t) => {
      const store = setup(t);
      const wall = store.get("walls/canonical") as Doc;
      wall.review = reviewed;
      const manifest = store.get("ownedAssets/logical") as Doc;
      if (failure === "owner") (manifest.provenance as Doc).uid = "another";
      if (failure === "missing") store.delete("ownedAssets/logical");
      if (failure === "deleted") manifest.status = "deleted";
      if (failure === "incarnation") manifest.incarnation = 2;
      if (failure === "nanos") manifest.incarnationNanos = 1000001;
      if (failure === "objectId") (manifest.original as Doc).objectId = "4".repeat(64);
      if (failure === "path") manifest.canonicalPath = "walls/other";
      if (failure === "duplicate") store.set("walls/duplicate", {...wall});
      if (failure === "receipt") store.delete(`githubUploads/file_${hash(`walls\0logical.jpg\0${"a".repeat(40)}`)}`);
      if (failure === "intent") store.delete(`githubUploadIntents/path_${hash("walls\0logical.jpg")}`);
      if (failure === "legacy-provenance") manifest.provenance = {kind: "legacy", uid: "creator"};
      if (failure === "studio") {
        Object.assign(wall, {email: STUDIO_ACCOUNT.email, origin: "studio", studioRunId: "run",
          studioCandidateId: "candidate"});
        store.set("studioRuns/run/candidates/candidate", {wallId: "canonical"});
      }
      const before = structuredClone([...store.entries()]);
      const awardRequest = failure === "studio" ? {...request,
        auth: {uid: "creator", token: {email: STUDIO_ACCOUNT.email}}} as typeof request : request;
      assert.equal((await awardCoins.run(awardRequest)).changed, false);
      assert.deepEqual([...store.entries()], before);
    });
  }
}

test("a user-owned upload with a spoofed Studio marker still earns first-upload coins", async (t) => {
  const store = setup(t, "owned");
  const wall = store.get("walls/canonical") as Doc;
  Object.assign(wall, {origin: "studio", studioRunId: "run", studioCandidateId: "candidate"});
  store.set("studioRuns/run/candidates/candidate", {wallId: "another-wall"});

  const result = await awardCoins.run(request);
  assert.equal(result.changed, true);
  assert.equal(store.get("usersv2/creator")?.coins, 59);
});
