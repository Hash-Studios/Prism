import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {createHash} from "node:crypto";
import {awardCoins} from "../coinsCallables";
import {installFakeDb, type Doc} from "./fakeDb";

const hash = (value: string) => createHash("sha256").update(value).digest("hex");
const request = {auth: {uid: "creator", token: {email: "creator@example.com"}},
  data: {action: "firstWallpaperUpload", sourceTag: "test"}} as unknown as Parameters<typeof awardCoins.run>[0];

function setup(t: TestContext, kind = "github") {
  for (const [key, value] of Object.entries({GH_USERNAME: "hash", GH_REPO_WALLS: "walls",
    OWNED_ASSET_BUCKET: "private-test", GCLOUD_PROJECT: "prism-wallpapers"})) {
    const previous = process.env[key];
    process.env[key] = value;
    t.after(() => { if (previous === undefined) delete process.env[key]; else process.env[key] = previous; });
  }
  const store = installFakeDb(t, {
    "usersv2/creator": {coins: 9, email: "creator@example.com"},
    "walls/canonical": {id: "logical", email: "creator@example.com", review: false, wallpaper_provider: "Prism",
      originalProtected: true, originalGeneration: "123", wallpaper_url: "", wallpaper_path: "", wallpaper_sha: "",
      thumb_path: "", thumb_sha: "",
      wallpaper_thumb: "https://asia-south1-prism-wallpapers.cloudfunctions.net/ownedThumbnail/logical"},
    "ownedAssets/logical": {status: "ready", canonicalPath: "walls/canonical", incarnation: 1,
      incarnationNanos: 1000000, provenance: {kind, uid: "creator"},
      originalUrl: kind === "owned" ? "" : "https://raw.githubusercontent.com/hash/walls/main/logical.jpg",
      thumbUrl: "https://raw.githubusercontent.com/hash/walls/main/thumb_logical.jpg",
      original: {generation: "123", path: "logical.jpg", sha: "a".repeat(40)},
      thumb: {path: "thumb_logical.jpg", sha: "b".repeat(40)}},
  });
  for (const [path, sha] of [["logical.jpg", "a".repeat(40)], ["thumb_logical.jpg", "b".repeat(40)]]) {
    const privateOriginal = kind === "owned" && path === "logical.jpg";
    const namespace = privateOriginal ? "owned_" : "";
    const retainedAsset = {uid: "creator", repo: "walls", path, sha, generation: "123", bucket: "private-test",
      object: `${privateOriginal ? "private-originals" : "retained"}/${hash(`walls\0${path}\0${sha}`)}`,
      sha256: "c".repeat(64), ...(privateOriginal ? {sourceKind: "owned"} : {})};
    const manifest = store.get("ownedAssets/logical") as Doc;
    manifest[path === "logical.jpg" ? "original" : "thumb"] = retainedAsset;
    store.set(`githubUploads/${namespace}file_${hash(`walls\0${path}\0${sha}`)}`,
      {uid: "creator", repo: "walls", path, sha, retainedAsset, ...(privateOriginal ? {sourceKind: "owned"} : {})});
    store.set(`githubUploadIntents/${namespace}path_${hash(`walls\0${path}`)}`, {uid: "creator", repo: "walls", path,
      ...(privateOriginal ? {sourceKind: "owned", retainedAsset} : {}),
      blobSha: sha, status: "complete", response: {content: {path, sha,
        download_url: privateOriginal ? "" : `https://raw.githubusercontent.com/hash/walls/main/${path}`}}});
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

for (const failure of ["owner", "missing", "deleted", "incarnation", "nanos", "generation", "path", "duplicate", "studio",
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
      if (failure === "generation") (manifest.original as Doc).generation = "456";
      if (failure === "path") manifest.canonicalPath = "walls/other";
      if (failure === "duplicate") store.set("walls/duplicate", {...wall});
      if (failure === "receipt") store.delete(`githubUploads/file_${hash(`walls\0logical.jpg\0${"a".repeat(40)}`)}`);
      if (failure === "intent") store.delete(`githubUploadIntents/path_${hash("walls\0logical.jpg")}`);
      if (failure === "legacy-provenance") manifest.provenance = {kind: "legacy", uid: "creator"};
      if (failure === "studio") {
        Object.assign(wall, {origin: "studio", studioRunId: "run", studioCandidateId: "candidate"});
        store.set("studioRuns/run/candidates/candidate", {wallId: "canonical"});
      }
      const before = structuredClone([...store.entries()]);
      assert.equal((await awardCoins.run(request)).changed, false);
      assert.deepEqual([...store.entries()], before);
    });
  }
}
