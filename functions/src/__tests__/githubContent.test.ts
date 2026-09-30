import assert from "node:assert/strict";
import {createHash} from "node:crypto";
import test, {type TestContext} from "node:test";
import {db} from "../common";

import {
  canDeleteUpload,
  base64DecodedBytes,
  githubDeleteFile,
  githubPutFile,
  isAllowedRepo,
  isValidBase64,
  isValidGithubPath,
  weekStartUtc,
} from "../githubContent";

const env = {GH_REPO_WALLS: "walls", GH_REPO_SETUPS: "setups"};
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const run = (fn: {run: (request: any) => Promise<any>}, request: Record<string, unknown>) => fn.run(request);

test("allows configured repositories only", () => {
  assert.equal(isAllowedRepo("walls", env), true);
  assert.equal(isAllowedRepo("other", env), false);
  assert.equal(isAllowedRepo("owner/walls", env), false);
});

test("isValidBase64 accepts canonical data and rejects malformed encodings", () => {
  assert.equal(isValidBase64("AA=="), true);
  assert.equal(isValidBase64("AQID"), true);
  assert.equal(isValidBase64("AA="), false);
  assert.equal(isValidBase64("AQ!D"), false);
  assert.equal(isValidBase64("AB=="), false);
});

test("the 15 MiB base64 boundary is valid", () => {
  const bytes = Buffer.alloc(15 * 1024 * 1024);
  const encoded = bytes.toString("base64");
  assert.equal(base64DecodedBytes(encoded), bytes.length);
  assert.equal(isValidBase64(encoded), true);
});

test("rejects unsafe GitHub content paths", () => {
  assert.equal(isValidGithubPath("images/wall.png"), true);
  assert.equal(isValidGithubPath("../secret"), false);
  assert.equal(isValidGithubPath("images/../secret"), false);
  assert.equal(isValidGithubPath("/secret"), false);
  assert.equal(isValidGithubPath("images/"), false);
});

test("canDeleteUpload: admins can delete without an ownership record", () => {
  assert.equal(canDeleteUpload(undefined, "user-1", "walls", "images/a.png", true), true);
});

test("canDeleteUpload: rejects a missing ownership record", () => {
  assert.equal(canDeleteUpload(undefined, "user-1", "walls", "images/a.png", false), false);
});

test("canDeleteUpload: rejects a record owned by another uid", () => {
  const record = {uid: "user-2", repo: "walls", path: "images/a.png"};
  assert.equal(canDeleteUpload(record, "user-1", "walls", "images/a.png", false), false);
});

test("canDeleteUpload: rejects a record for a different repo or path", () => {
  const record = {uid: "user-1", repo: "walls", path: "images/a.png"};
  assert.equal(canDeleteUpload(record, "user-1", "setups", "images/a.png", false), false);
  assert.equal(canDeleteUpload(record, "user-1", "walls", "images/b.png", false), false);
});

test("canDeleteUpload: allows the owner to delete their own upload", () => {
  const record = {uid: "user-1", repo: "walls", path: "images/a.png"};
  assert.equal(canDeleteUpload(record, "user-1", "walls", "images/a.png", false), true);
});

function uploadStore(t: TestContext, seed: Record<string, Record<string, unknown>>, failReceiptWrites = 0) {
  const docs = new Map<string, Record<string, unknown>>(Object.entries(seed));
  let transactionQueue = Promise.resolve();
  const set = (path: string, data: Record<string, unknown>) => {
    if (path.startsWith("githubUploads/") && failReceiptWrites > 0) {
      failReceiptWrites--;
      throw new Error("temporary receipt write failure");
    }
    docs.set(path, data);
  };
  const ref = (path: string) => ({
    path,
    get: async () => ({exists: docs.has(path), data: () => docs.get(path)}),
    set: async (data: Record<string, unknown>) => set(path, data),
    delete: async () => void docs.delete(path),
  });
  t.mock.method(db, "collection", (name: string) => ({doc: (id: string) => ref(`${name}/${id}`)}));
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => {
    const run = transactionQueue.then(async () => {
      const writes: (() => void)[] = [];
      let hasWritten = false;
      const tx = {
        get: async (document: {path: string}) => {
          if (hasWritten) throw new Error("Firestore transactions require reads before writes");
          const value = docs.get(document.path);
          return {exists: value !== undefined, data: () => value};
        },
        update: (document: {path: string}, data: Record<string, unknown>) => {
          hasWritten = true;
          writes.push(() => docs.set(document.path, {...docs.get(document.path), ...data}));
        },
        set: (document: {path: string}, data: Record<string, unknown>) => {
          hasWritten = true;
          writes.push(() => set(document.path, data));
        },
        delete: (document: {path: string}) => {
          hasWritten = true;
          writes.push(() => void docs.delete(document.path));
        },
      };
      const result = await callback(tx);
      writes.forEach((write) => write());
      return result;
    });
    transactionQueue = run.then(() => undefined, () => undefined);
    return run;
  });
  return docs;
}

function testGithubEnvironment(t: TestContext) {
  const prior = {token: process.env.GH_TOKEN, username: process.env.GH_USERNAME, walls: process.env.GH_REPO_WALLS};
  t.after(() => {
    for (const [key, value] of Object.entries({GH_TOKEN: prior.token, GH_USERNAME: prior.username, GH_REPO_WALLS: prior.walls})) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });
  process.env.GH_TOKEN = "test-token";
  process.env.GH_USERNAME = "owner";
  process.env.GH_REPO_WALLS = "walls";
}

async function deleteRequest(t: TestContext, upload: Record<string, unknown>, stats: Record<string, unknown>) {
  testGithubEnvironment(t);
  const docs = uploadStore(t, {"githubUploads/sha": upload, "githubUploadStats/u": stats});
  t.mock.method(globalThis, "fetch", async () => ({ok: true, json: async () => ({})}));
  const result = await run(githubDeleteFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "thumb_a.jpg", message: "delete", sha: "sha"},
  });
  return {docs, result};
}

test("githubDeleteFile releases quota charged by this week's free wall preview", async (t) => {
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const {docs, result} = await deleteRequest(t, {
    uid: "u", repo: "walls", path: "thumb_a.jpg", weeklyQuotaCharged: true, uploadWeek: week,
  }, {day, count: 2, week, weekCount: 1});
  assert.deepEqual(result, {ok: true});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
});

test("githubDeleteFile does not release a premium upload's weekly quota", async (t) => {
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const {docs} = await deleteRequest(t, {
    uid: "u", repo: "walls", path: "thumb_a.jpg", weeklyQuotaCharged: false, uploadWeek: week,
  }, {day, count: 2, week, weekCount: 2});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 2);
});

test("githubDeleteFile does not release this week's quota for an older upload", async (t) => {
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const oldWeek = new Date(Date.parse(`${week}T00:00:00Z`) - 7 * 86_400_000).toISOString().slice(0, 10);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const {docs} = await deleteRequest(t, {
    uid: "u", repo: "walls", path: "thumb_a.jpg", weeklyQuotaCharged: true, uploadWeek: oldWeek,
  }, {day, count: 2, week, weekCount: 2});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 2);
});

test("githubDeleteFile refunds once and fences a duplicate delete from a same-path reupload", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "githubUploads/sha": {uid: "u", repo: "walls", path: "thumb_wall.jpg", sha: "sha",
      weeklyQuotaCharged: true, uploadWeek: week},
    "githubUploadStats/u": {day, count: 2, week, weekCount: 1},
  });
  let deleteCount = 0;
  const remote = new Map<string, Record<string, unknown>>();
  const blobSha = createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex");
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const path = decodeURIComponent(new URL(rawUrl.toString()).pathname.split("/contents/")[1]);
    if (init.method === "DELETE") {
      deleteCount++;
      remote.delete(path);
      return {ok: true, status: 200, json: async () => ({})};
    }
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ? {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({})};
    }
    const content = {path, sha: blobSha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const remove = () => run(githubDeleteFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "delete", sha: "sha"},
  });

  await remove();
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
  await assert.rejects(remove, {code: "permission-denied"});
  await run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  });
  assert.equal(deleteCount, 1);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubDeleteFile blocks a duplicate delete and reupload while delete is in flight", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "githubUploads/sha": {uid: "u", repo: "walls", path: "thumb_wall.jpg", sha: "sha",
      weeklyQuotaCharged: true, uploadWeek: week},
    "githubUploadStats/u": {day, count: 1, week, weekCount: 1},
    "usersv2/u": {premium: false},
  });
  let deleteCount = 0;
  let started!: () => void;
  const deleteStarted = new Promise<void>((resolve) => {
    started = resolve;
  });
  let finishDelete!: () => void;
  const deleteResponse = new Promise<void>((resolve) => {
    finishDelete = resolve;
  });
  const blobSha = createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex");
  const remote = new Map<string, Record<string, unknown>>();
  t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
    if (init.method === "DELETE") {
      deleteCount++;
      started();
      remote.delete("thumb_wall.jpg");
      await deleteResponse;
      return {ok: true, status: 200, json: async () => ({})};
    }
    if (init.method === "GET") {
      const content = remote.get("thumb_wall.jpg");
      return content ? {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({})};
    }
    const content = {path: "thumb_wall.jpg", sha: blobSha, download_url: "https://raw.example/thumb_wall.jpg"};
    remote.set("thumb_wall.jpg", content);
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const remove = () => run(githubDeleteFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "delete", sha: "sha"},
  });
  const firstDelete = remove();
  await deleteStarted;
  await assert.rejects(remove, {code: "resource-exhausted"});
  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  }), {code: "failed-precondition"});
  assert.equal(deleteCount, 1);
  finishDelete();
  await firstDelete;
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
  await run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  });
  assert.equal(deleteCount, 1);
  assert.equal(remote.get("thumb_wall.jpg")?.sha, blobSha);
});

test("githubDeleteFile recovers a lost response after its lease and refunds only once", async (t) => {
  testGithubEnvironment(t);
  let nowMs = Date.parse("2026-10-01T12:00:00Z");
  t.mock.method(Date, "now", () => nowMs);
  const week = weekStartUtc(nowMs);
  const docs = uploadStore(t, {
    "githubUploads/sha": {uid: "u", repo: "walls", path: "thumb_wall.jpg", sha: "sha",
      weeklyQuotaCharged: true, uploadWeek: week},
    "githubUploadStats/u": {day: "2026-10-01", count: 1, week, weekCount: 2},
  });
  let deleteCount = 0;
  t.mock.method(globalThis, "fetch", async () => {
    if (++deleteCount === 1) throw new Error("response lost after GitHub deletion");
    return {ok: false, status: 404, json: async () => ({message: "Not Found"})};
  });
  const remove = () => run(githubDeleteFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "delete", sha: "sha"},
  });

  await assert.rejects(remove, {code: "internal"});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 2);
  assert.equal(docs.has("githubUploads/sha"), true);
  await assert.rejects(remove, {code: "resource-exhausted"});
  assert.equal(deleteCount, 1);
  nowMs += 120_000;
  assert.deepEqual(await remove(), {ok: true});
  assert.equal(deleteCount, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  assert.equal(docs.has("githubUploads/sha"), false);
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploadIntents/")), false);
  await assert.rejects(remove, {code: "permission-denied"});
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubPutFile keeps a main wall upload when a failed preview is retried", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  });
  const remote = new Map<string, Record<string, unknown>>();
  let previewPutCount = 0;
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const url = new URL(rawUrl.toString());
    const path = decodeURIComponent(url.pathname.split("/contents/")[1]);
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ?
        {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({message: "Not Found"})};
    }
    const body = JSON.parse(init.body as string) as {content: string};
    const bytes = Buffer.from(body.content, "base64");
    const sha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
    const content = {path, sha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    if (path === "thumb_wall.jpg" && ++previewPutCount === 1) throw new Error("response lost after GitHub commit");
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const put = (path: string) => run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path, message: path, contentBase64: "/9j/"},
  });

  await put("wall.jpg");
  await assert.rejects(() => put("thumb_wall.jpg"), {code: "internal"});
  assert.equal(docs.get("githubUploadStats/u")?.count, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "v"},
    data: {repo: "walls", path: "thumb_wall.jpg", message: "thumb_wall.jpg", contentBase64: "/9j/"},
  }), {code: "permission-denied"});
  const recovered = await put("thumb_wall.jpg");
  assert.deepEqual(recovered, {content: remote.get("thumb_wall.jpg")});
  assert.equal(docs.get("githubUploadStats/u")?.count, 3);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  assert.equal(previewPutCount, 1);
});

test("githubPutFile retries receipt persistence without charging the weekly quota twice", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  }, 1);
  const remote = new Map<string, Record<string, unknown>>();
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
  let putCount = 0;
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const url = new URL(rawUrl.toString());
    const path = decodeURIComponent(url.pathname.split("/contents/")[1]);
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ?
        {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({message: "Not Found"})};
    }
    putCount++;
    const content = {path, sha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    return {ok: true, status: 201, json: async () => ({content})};
  });
  const put = () => run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "thumb_wall.jpg", message: "thumb_wall.jpg", contentBase64: "/9j/"},
  });

  await assert.rejects(put, /temporary receipt write failure/);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  const recovered = await put();
  assert.deepEqual(recovered, {content: remote.get("thumb_wall.jpg")});
  assert.equal(putCount, 1);
  assert.equal(docs.get("githubUploadStats/u")?.count, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubPutFile rolls back weekly quota after a definite GitHub rejection", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  });
  let puts = 0;
  t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
    if (init.method === "GET") return {ok: false, status: 404, json: async () => ({})};
    puts++;
    return {ok: false, status: 422, json: async () => ({message: "validation failed"})};
  });

  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  }), {code: "internal"});
  assert.equal(puts, 1);
  assert.equal(docs.get("githubUploadStats/u")?.count, 1);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 0);
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploadIntents/")), false);
});

for (const premiumInitially of [false, true]) {
  test(`githubPutFile revalidates an unwritten retry after ${premiumInitially ? "a Free downgrade" : "a new week"}`, async (t) => {
    testGithubEnvironment(t);
    let nowMs = Date.parse("2026-10-01T12:00:00Z");
    t.mock.method(Date, "now", () => nowMs);
    const week = weekStartUtc(nowMs);
    const docs = uploadStore(t, {
      "usersv2/u": {premium: premiumInitially},
      "githubUploadStats/u": {day: "2026-10-01", count: 0, week, weekCount: 0},
    });
    const blobSha = createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex");
    let puts = 0;
    t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
      if (init.method === "GET") return {ok: false, status: 404, json: async () => ({})};
      if (++puts === 1) throw new Error("GitHub was unreachable before writing");
      return {ok: true, status: 201, json: async () => ({content: {
        path: "thumb_wall.jpg", sha: blobSha, download_url: "https://raw.example/thumb_wall.jpg",
      }})};
    });
    const upload = () => run(githubPutFile, {
      auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
    });
    await assert.rejects(upload, {code: "internal"});
    assert.equal(docs.get("githubUploadStats/u")?.weekCount, premiumInitially ? 0 : 1);

    if (!premiumInitially) nowMs = Date.parse("2026-10-05T12:00:00Z");
    const currentWeek = weekStartUtc(nowMs);
    docs.set("usersv2/u", {premium: false});
    docs.set("githubUploadStats/u", {
      day: new Date(nowMs).toISOString().slice(0, 10), count: 1, week: currentWeek, weekCount: 3,
    });
    await assert.rejects(upload, {code: "resource-exhausted"});
    assert.equal(puts, 1);
    docs.set("githubUploadStats/u", {...docs.get("githubUploadStats/u"), weekCount: 2});
    assert.deepEqual(await upload(), {content: {
      path: "thumb_wall.jpg", sha: blobSha, download_url: "https://raw.example/thumb_wall.jpg",
    }});
    assert.equal(puts, 2);
    assert.equal(docs.get("githubUploadStats/u")?.weekCount, 3);
    const receipt = [...docs.entries()].find(([key]) => key.startsWith("githubUploads/"))?.[1];
    assert.equal(receipt?.weeklyQuotaCharged, true);
    assert.equal(receipt?.uploadWeek, currentWeek);
  });
}

test("githubPutFile permits only one simultaneous upload for a path", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/u": {premium: false},
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
  });
  let puts = 0;
  let started!: () => void;
  const putStarted = new Promise<void>((resolve) => {
    started = resolve;
  });
  let finishPut!: () => void;
  const putResponse = new Promise<void>((resolve) => {
    finishPut = resolve;
  });
  t.mock.method(globalThis, "fetch", async (_url: string | URL | Request, init: RequestInit) => {
    if (init.method === "GET") return {ok: false, status: 404, json: async () => ({})};
    puts++;
    started();
    await putResponse;
    return {ok: true, status: 201, json: async () => ({content: {
      path: "thumb_wall.jpg", sha: createHash("sha1").update("blob 3\0").update(Buffer.from("/9j/", "base64")).digest("hex"),
      download_url: "https://raw.example/thumb_wall.jpg",
    }})};
  });
  const upload = () => run(githubPutFile, {
    auth: {uid: "u"}, data: {repo: "walls", path: "thumb_wall.jpg", message: "upload", contentBase64: "/9j/"},
  });
  const firstUpload = upload();
  await putStarted;
  await assert.rejects(upload, {code: "resource-exhausted"});
  assert.equal(puts, 1);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
  finishPut();
  await firstUpload;
  assert.equal(docs.get("githubUploadStats/u")?.count, 2);
  assert.equal(docs.get("githubUploadStats/u")?.weekCount, 1);
});

test("githubPutFile does not claim a pre-existing public file with matching bytes", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "usersv2/v": {premium: false},
    "githubUploadStats/v": {day, count: 0, week, weekCount: 0},
  });
  const bytes = Buffer.from("/9j/", "base64");
  const sha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
  t.mock.method(globalThis, "fetch", async () => ({
    ok: true,
    status: 200,
    json: async () => ({path: "thumb_public.jpg", sha, download_url: "https://raw.example/thumb_public.jpg"}),
  }));

  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "v"},
    data: {repo: "walls", path: "thumb_public.jpg", message: "thumb_public.jpg", contentBase64: "/9j/"},
  }), {code: "already-exists"});
  assert.equal([...docs.keys()].some((key) => key.startsWith("githubUploadIntents/")), false);
  assert.equal(docs.get("githubUploadStats/v")?.weekCount, 0);
});

test("githubPutFile rejects malformed base64 before reserving upload quota", async (t) => {
  testGithubEnvironment(t);
  t.mock.method(db, "runTransaction", () => {
    throw new Error("must not reserve quota for malformed content");
  });
  await assert.rejects(() => run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "wall.jpg", message: "wall", contentBase64: "AQ!D"},
  }), {code: "invalid-argument"});
});

test("githubDeleteFile rejects path-like SHAs before Firestore lookup", async (t) => {
  testGithubEnvironment(t);
  t.mock.method(db, "collection", () => {
    throw new Error("must not look up a path-like document ID");
  });
  await assert.rejects(() => run(githubDeleteFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "wall.jpg", message: "wall", sha: "../wall"},
  }), {code: "invalid-argument"});
});

test("githubPutFile keeps separate delete records when files share a blob SHA", async (t) => {
  testGithubEnvironment(t);
  const nowMs = Date.now();
  const week = weekStartUtc(nowMs);
  const day = new Date(nowMs).toISOString().slice(0, 10);
  const docs = uploadStore(t, {
    "githubUploadStats/u": {day, count: 0, week, weekCount: 0},
    "githubUploadStats/v": {day, count: 0, week, weekCount: 0},
  });
  const bytes = Buffer.from("/9j/", "base64");
  const sameSha = createHash("sha1").update("blob " + bytes.length + "\0").update(bytes).digest("hex");
  const remote = new Map<string, Record<string, unknown>>();
  t.mock.method(globalThis, "fetch", async (rawUrl: string | URL | Request, init: RequestInit) => {
    const url = new URL(rawUrl.toString());
    const path = decodeURIComponent(url.pathname.split("/contents/")[1]);
    if (init.method === "GET") {
      const content = remote.get(path);
      return content ?
        {ok: true, status: 200, json: async () => content} :
        {ok: false, status: 404, json: async () => ({message: "Not Found"})};
    }
    if (init.method === "DELETE") {
      remote.delete(path);
      return {ok: true, status: 200, json: async () => ({})};
    }
    const content = {path, sha: sameSha, download_url: `https://raw.example/${path}`};
    remote.set(path, content);
    return {ok: true, status: 201, json: async () => ({content})};
  });

  for (const [uid, path] of [["u", "a.jpg"], ["v", "b.jpg"]]) {
    await run(githubPutFile, {
      auth: {uid},
      data: {repo: "walls", path, message: path, contentBase64: "/9j/"},
    });
  }
  assert.deepEqual(
    [...docs.entries()].filter(([key]) => key.startsWith("githubUploads/")).map(([, record]) => record.path).sort(),
    ["a.jpg", "b.jpg"],
  );

  for (const [uid, path] of [["u", "a.jpg"], ["v", "b.jpg"]]) {
    await run(githubDeleteFile, {
      auth: {uid},
      data: {repo: "walls", path, message: path, sha: sameSha},
    });
  }
  assert.equal([...docs.keys()].filter((key) => key.startsWith("githubUploads/")).length, 0);
  await run(githubPutFile, {
    auth: {uid: "u"},
    data: {repo: "walls", path: "a.jpg", message: "a.jpg", contentBase64: "/9j/"},
  });
  assert.equal([...docs.keys()].filter((key) => key.startsWith("githubUploads/")).length, 1);
});
