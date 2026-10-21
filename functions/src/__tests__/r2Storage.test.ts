import assert from "node:assert/strict";
import test from "node:test";
import {R2Storage, r2Env, r2ObjectId} from "../r2Storage";

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

test("r2Env normalizes and rejects unsafe values for every R2 setting", (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  process.env = {...process.env};
  const names = ["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_PRIVATE_BUCKET",
    "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"] as const;

  for (const name of names) {
    delete process.env[name];
    assert.equal(r2Env(name), undefined, `${name} should be undefined when unset`);
    process.env[name] = "";
    assert.equal(r2Env(name), undefined, `${name} should be undefined when explicitly empty`);

    process.env[name] = " \tsetting-value\n ";
    assert.equal(r2Env(name), "setting-value", `${name} should trim surrounding whitespace`);

    process.env[name] = " \t\n ";
    assert.throws(() => r2Env(name), {
      message: `R2 storage configuration is invalid: ${name} is empty`,
    });

    for (const value of ["setting value", "setting\0value", "setting\u007fvalue"]) {
      process.env[name] = value;
      assert.throws(() => r2Env(name), {
        message: `R2 storage configuration is invalid: ${name} contains whitespace or control characters`,
      });
    }
  }
});

test("R2 trims a trailing newline from secret-store values before signing", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configure();
  for (const key of ["R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_PRIVATE_BUCKET",
    "R2_PREVIEW_BUCKET", "R2_PREVIEW_BASE_URL"]) process.env[key] = `${process.env[key]}\n`;
  const headers: Headers[] = [];
  // new Headers() throws "invalid header value" for a newline, like fetch does in the migration script.
  const storage = new R2Storage(async (_input, init) => {
    headers.push(new Headers(init?.headers));
    return new Response(null, {status: 404});
  }, () => new Date("2025-01-02T03:04:05.000Z"));
  assert.equal(await storage.head("private", "retained/abc"), null);
  assert.match(headers[0].get("authorization") ?? "", /^AWS4-HMAC-SHA256 Credential=test-access\/20250102\/auto\/s3\/aws4_request, /);
  assert.match(storage.presignGet("private-originals/abc", new Date("2025-01-02T03:06:05.000Z")),
    /^https:\/\/a{32}\.r2\.cloudflarestorage\.com\/private-assets\/.*X-Amz-Signature=9f50131a199b46d6588a53da9d5ce622d02ad84a53a4e428d044e8100d68cc71$/);
});

test("blank or inner-whitespace R2 values fail closed without echoing the value", (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  configure();
  process.env.R2_SECRET_ACCESS_KEY = " \n";
  assert.throws(() => new R2Storage(), /R2_SECRET_ACCESS_KEY is empty/);
  configure();
  process.env.R2_ACCESS_KEY_ID = "test-\naccess";
  assert.throws(() => new R2Storage(), (error: Error) =>
    /R2_ACCESS_KEY_ID contains whitespace or control characters/.test(error.message) && !error.message.includes("test-"));
  configure();
  process.env.R2_PRIVATE_BUCKET = "private\tassets";
  assert.throws(() => new R2Storage(), /R2_PRIVATE_BUCKET contains whitespace/);
});
