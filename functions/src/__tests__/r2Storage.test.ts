import assert from "node:assert/strict";
import test from "node:test";
import {R2Storage, r2ObjectId} from "../r2Storage";

function configure() {
  process.env.R2_ACCOUNT_ID = "a".repeat(32);
  process.env.R2_ACCESS_KEY_ID = "test-access";
  process.env.R2_SECRET_ACCESS_KEY = "test-secret";
  process.env.R2_PRIVATE_BUCKET = "private-assets";
  process.env.R2_PREVIEW_BUCKET = "public-previews";
  process.env.R2_PREVIEW_BASE_URL = "https://images.example.com";
}

test("R2 signs conditional create, HEAD, GET, and exact DELETE with SigV4", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configure();
  const bytes = Buffer.from("r2-image");
  const calls: {url: string; init?: RequestInit}[] = [];
  const request: typeof fetch = async (input, init) => {
    calls.push({url: String(input), init});
    const method = init?.method;
    if (method === "PUT") return new Response(null, {status: 200});
    if (method === "HEAD") {
      return new Response(null, {status: 200, headers: {"content-length": String(bytes.length),
        "content-type": "image/jpeg", "x-amz-meta-sha256": "digest", "x-amz-meta-uid": "u",
        "x-amz-meta-objectid": "object-id", "x-amz-meta-repo": "walls", "x-amz-meta-path": "a.jpg",
        "x-amz-meta-gitsha": "git-sha"}});
    }
    if (method === "GET") return new Response(bytes, {status: 200, headers: {"content-length": String(bytes.length)}});
    return new Response(null, {status: 204});
  };
  const storage = new R2Storage(request, () => new Date("2025-01-02T03:04:05.000Z"));
  await storage.put("private", "retained/abc", bytes, {sha256: "digest", uid: "u"}, "image/jpeg");
  const head = await storage.head("private", "retained/abc");
  const downloaded = await storage.get("private", "retained/abc");
  await storage.delete("private", "retained/abc");
  assert.equal(head?.objectId, "object-id");
  assert.deepEqual(downloaded, bytes);
  assert.equal(calls.length, 4);
  assert.match(calls[0].url, /\.r2\.cloudflarestorage\.com\/private-assets\/retained\/abc$/);
  assert.equal(new Headers(calls[0].init?.headers).get("if-none-match"), "*");
  for (const call of calls) assert.match(new Headers(call.init?.headers).get("authorization") ?? "", /^AWS4-HMAC-SHA256 /);
});

test("R2 presigned GET is short-lived and object IDs fence source kind and exact bytes", (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configure();
  const storage = new R2Storage(async () => new Response(null), () => new Date("2025-01-02T03:04:05.000Z"));
  const url = storage.presignGet("private-originals/abc", new Date("2025-01-02T03:06:05.000Z"));
  assert.match(url, /X-Amz-Expires=120/);
  assert.match(url, /X-Amz-Signature=[a-f0-9]{64}/);
  assert.equal(url, "https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.r2.cloudflarestorage.com/private-assets/private-originals/abc?" +
    "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=test-access%2F20250102%2Fauto%2Fs3%2Faws4_request&" +
    "X-Amz-Date=20250102T030405Z&X-Amz-Expires=120&X-Amz-SignedHeaders=host&" +
    "X-Amz-Signature=9f50131a199b46d6588a53da9d5ce622d02ad84a53a4e428d044e8100d68cc71");
  const identity = {uid: "u", repo: "walls", path: "a.jpg", sha: "a".repeat(40)};
  const digest = "b".repeat(64);
  assert.notEqual(r2ObjectId(identity, digest), r2ObjectId({...identity, sourceKind: "owned"}, digest));
  assert.notEqual(r2ObjectId(identity, digest), r2ObjectId(identity, "c".repeat(64)));
  assert.notEqual(r2ObjectId(identity, digest), r2ObjectId({...identity, uploadId: "next-upload"}, digest));
});

test("partial R2 config fails closed", (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  delete process.env.R2_ACCOUNT_ID;
  process.env.R2_ACCESS_KEY_ID = "partial";
  assert.throws(() => new R2Storage(), /incomplete/);
});
