import assert from "node:assert/strict";
import {test} from "node:test";
import {buildGithubInventory, createInventoryReport, GithubApiError, listGithubTree, resolvePinnedTree,
  validateMigrationCommit, validateReviewedInventory, type MigrationOptions, type MigrationWall} from "../scripts/migrateGithubToR2";

const sha = (c: string) => c.repeat(40);
const blob = (path: string, c: string, size = 10) => ({path, type: "blob", sha: sha(c), size});
const treeEntry = (path: string, c: string) => ({path, type: "tree", sha: sha(c)});
const commit = sha("f");

test("preserves recursive paths and metadata for blobs, trees, commits, and gitlinks", async () => {
  const tree = await listGithubTree(async () => ({truncated: false, tree: [
    blob("a.jpg", "a", 11), treeEntry("dir", "b"), {path: "submodule", type: "commit", sha: sha("c")},
    {path: "vendor", type: "commit", sha: sha("d"), size: 0}, blob("dir/b.jpg", "e", 12),
  ]}), "/repos/o/r", commit);
  assert.deepEqual(tree, {truncated: false, entries: [
    {path: "a.jpg", type: "blob", sha: sha("a"), size: 11},
    {path: "dir", type: "tree", sha: sha("b"), size: 0},
    {path: "submodule", type: "commit", sha: sha("c"), size: 0},
    {path: "vendor", type: "commit", sha: sha("d"), size: 0},
    {path: "dir/b.jpg", type: "blob", sha: sha("e"), size: 12},
  ]});
});

test("walks three levels and retains duplicate tree SHAs at distinct paths", async () => {
  const calls: string[] = [];
  const tree = await listGithubTree(async (path) => {
    calls.push(path);
    if (path.endsWith("?recursive=1")) throw new GithubApiError(500, "server error");
    if (path.endsWith(`/${commit}`)) return {truncated: false, tree: [treeEntry("left", "b"), treeEntry("right", "b")]};
    if (path.endsWith(`/${sha("b")}`)) return {truncated: false, tree: [treeEntry("inner", "c")]};
    if (path.endsWith(`/${sha("c")}`)) return {truncated: false, tree: [blob("wall.jpg", "d", 31)]};
    throw new Error(`unexpected ${path}`);
  }, "/repos/o/r", commit);
  assert.deepEqual(tree.entries.map(({path, type, sha: objectSha, size}) => [path, type, objectSha, size]), [
    ["left", "tree", sha("b"), 0], ["left/inner", "tree", sha("c"), 0], ["left/inner/wall.jpg", "blob", sha("d"), 31],
    ["right", "tree", sha("b"), 0], ["right/inner", "tree", sha("c"), 0], ["right/inner/wall.jpg", "blob", sha("d"), 31],
  ]);
  assert.equal(calls.length, 6);
});

test("recursive and level-by-level listing produce the same normalized tree", async () => {
  const recursive = await listGithubTree(async () => ({truncated: false, tree: [
    blob("wall.jpg", "a", 17), treeEntry("assets", "b"), blob("assets/thumb.jpg", "c", 18),
    {path: "vendor", type: "commit", sha: sha("d")},
  ]}), "/repos/o/r", commit);
  const fallback = await listGithubTree(async (path) => {
    if (path.endsWith("?recursive=1")) throw new GithubApiError(503, "server error");
    if (path.endsWith(`/${commit}`)) {
      return {truncated: false, tree: [blob("wall.jpg", "a", 17), treeEntry("assets", "b"),
        {path: "vendor", type: "commit", sha: sha("d")}]};
    }
    if (path.endsWith(`/${sha("b")}`)) return {truncated: false, tree: [blob("thumb.jpg", "c", 18)]};
    throw new Error(`unexpected ${path}`);
  }, "/repos/o/r", commit);
  assert.deepEqual(fallback, recursive);
});

test("default GitHub fetch wraps HTTP 5xx and resolves the tree through the fallback", async (t) => {
  const pinned = sha("1");
  const calls: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    const url = String(input);
    calls.push(url);
    if (url.endsWith("/commits/main")) return new Response(JSON.stringify({sha: pinned}), {status: 200});
    if (url.endsWith(`/${pinned}?recursive=1`)) return new Response("{}", {status: 503});
    if (url.endsWith(`/git/trees/${pinned}`)) {
      return new Response(JSON.stringify({truncated: false,
        tree: [blob("wall.jpg", "a", 27), {path: "vendor", type: "commit", sha: sha("b")}]}), {status: 200});
    }
    throw new Error(`unexpected ${url}`);
  });

  const result = await resolvePinnedTree("o", "r", "main");
  assert.equal(result.commit, pinned);
  assert.deepEqual(result.tree, {truncated: false, entries: [
    {path: "wall.jpg", type: "blob", sha: sha("a"), size: 27},
    {path: "vendor", type: "commit", sha: sha("b"), size: 0},
  ]});
  assert.deepEqual(calls, ["https://api.github.com/repos/o/r/commits/main",
    `https://api.github.com/repos/o/r/git/trees/${pinned}?recursive=1`,
    `https://api.github.com/repos/o/r/git/trees/${pinned}`]);
});

test("default GitHub fetch preserves 4xx errors without fallback", async (t) => {
  const pinned = sha("1");
  const calls: string[] = [];
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    const url = String(input);
    calls.push(url);
    return url.endsWith("/commits/main") ? new Response(JSON.stringify({sha: pinned}), {status: 200}) :
      new Response("{}", {status: 403});
  });
  await assert.rejects(resolvePinnedTree("o", "r", "main"), (error) => {
    assert.ok(error instanceof GithubApiError);
    assert.equal(error.status, 403);
    return true;
  });
  assert.equal(calls.length, 2);
});

test("default GitHub fetch propagates transport failures", async (t) => {
  const pinned = sha("1");
  const calls: string[] = [];
  const expected = new Error("network unavailable");
  t.mock.method(globalThis, "fetch", async (input: string | URL | Request) => {
    const url = String(input);
    calls.push(url);
    if (url.endsWith("/commits/main")) return new Response(JSON.stringify({sha: pinned}), {status: 200});
    throw expected;
  });
  await assert.rejects(resolvePinnedTree("o", "r", "main"), (error) => error === expected);
  assert.equal(calls.length, 2);
});

test("refuses inventory construction for truncation in recursive, root, and nested responses", async (t) => {
  const rootPath = "/repos/o/r";
  const scenarios: [string, (path: string) => Promise<unknown>][] = [
    ["recursive", async () => ({truncated: true, tree: [blob("a.jpg", "a")]})],
    ["fallback root", async (path) => path.endsWith("?recursive=1") ?
      Promise.reject(new GithubApiError(500, "server error")) : {truncated: true, tree: [blob("a.jpg", "a")]}],
    ["fallback subtree", async (path) => path.endsWith("?recursive=1") ? Promise.reject(new GithubApiError(500, "server error")) :
      path.endsWith(`/${commit}`) ? {truncated: false, tree: [treeEntry("dir", "b")]} :
        {truncated: true, tree: [blob("a.jpg", "a")]}],
  ];
  for (const [name, fetchJson] of scenarios) {
    await t.test(name, async () => {
      const listed = await listGithubTree(fetchJson, rootPath, commit);
      assert.equal(listed.truncated, true);
      assert.throws(() => buildGithubInventory([], listed, {owner: "o", repo: "r", commit, apply: false,
        allowReviewedLegacy: false}), /truncated/);
    });
  }
});

test("rejects unsafe joined paths from recursive, fallback-root, and fallback-nested responses", async (t) => {
  const unsafe = ["", ".", "..", "../escape", "a/../escape", "a//b", "a/", "/absolute", "a\\b",
    "a\u0000b", "a\u001fb", "a\u007fb", "a\u0085b", "a\u009fb"];
  for (const value of unsafe) {
    for (const mode of ["recursive", "fallback-root", "fallback-nested"] as const) {
      await t.test(`${mode}: ${JSON.stringify(value)}`, async () => {
        await assert.rejects(listGithubTree(async (path) => {
          if (path.endsWith("?recursive=1")) {
            if (mode === "recursive") return {truncated: false, tree: [blob(value, "a")]};
            throw new GithubApiError(500, "fallback required");
          }
          if (path.endsWith(`/${commit}`)) {
            return {truncated: false, tree: mode === "fallback-nested" ?
              [treeEntry("dir", "b")] : [blob(value, "a")]};
          }
          return {truncated: false, tree: [blob(value, "a")]};
        }, "/repos/o/r", commit), /invalid/);
      });
    }
  }
});

test("does not fall back for GitHub 4xx or a non-GitHub error, preserving the error", async (t) => {
  for (const status of [400, 401, 403, 404, 422, 429]) {
    await t.test(String(status), async () => {
      const expected = new GithubApiError(status, `GitHub API failed (${status})`);
      let calls = 0;
      await assert.rejects(listGithubTree(async () => {
        calls++; throw expected;
      }, "/repos/o/r", commit), (error) => error === expected);
      assert.equal(calls, 1);
    });
  }
  const expected = new Error("transport failed");
  let calls = 0;
  await assert.rejects(listGithubTree(async () => {
    calls++; throw expected;
  }, "/repos/o/r", commit), (error) => error === expected);
  assert.equal(calls, 1);
});

test("falls back on GitHub 5xx but propagates fallback root and child errors without retry", async (t) => {
  for (const status of [500, 502, 503, 599]) {
    await t.test(`recursive ${status}`, async () => {
      const calls: string[] = [];
      const listed = await listGithubTree(async (path) => {
        calls.push(path);
        if (path.endsWith("?recursive=1")) throw new GithubApiError(status, "server error");
        return {truncated: false, tree: [blob("a.jpg", "a")]};
      }, "/repos/o/r", commit);
      assert.deepEqual(listed.entries.map((entry) => entry.path), ["a.jpg"]);
      assert.equal(calls.length, 2);
    });
  }
  for (const failedChild of [false, true]) {
    for (const failure of [new GithubApiError(403, "forbidden"),
      new GithubApiError(503, "unavailable"), new Error("transport failed")]) {
      await t.test(
        `${failedChild ? "child" : "root"} failure: ${failure.message}`, async () => {
          let recursive = true;
          const calls: string[] = [];
          await assert.rejects(listGithubTree(async (path) => {
            calls.push(path);
            if (recursive) {
              recursive = false; throw new GithubApiError(500, "fallback required");
            }
            if (!failedChild || path.endsWith(`/${commit}`)) {
              if (failedChild) return {truncated: false, tree: [treeEntry("dir", "b")]};
              throw failure;
            }
            throw failure;
          }, "/repos/o/r", commit), (error) => error === failure);
          assert.equal(calls.length, failedChild ? 3 : 2);
        });
    }
  }
});

test("a malformed recursive tree is not treated as a reason to fall back", async () => {
  let calls = 0;
  await assert.rejects(listGithubTree(async () => {
    calls++; return {tree: "not-an-array"};
  }, "/repos/o/r", commit), /invalid/);
  assert.equal(calls, 1);
});

test("a flat tree of 22,499 blobs fits in one fallback-level request", async () => {
  const entries = Array.from({length: 22_499}, (_, index) => blob(`wall-${index}.jpg`, "a", index + 1));
  let calls = 0;
  const listed = await listGithubTree(async (path) => {
    calls++;
    if (path.endsWith("?recursive=1")) throw new GithubApiError(500, "server error");
    return {truncated: false, tree: entries};
  }, "/repos/o/r", commit);
  assert.equal(calls, 2);
  assert.equal(listed.entries.length, 22_499);
  assert.deepEqual(listed.entries, entries);
});

test("resolves a moving ref once and uses the pinned SHA for recursive and fallback root calls", async () => {
  const calls: string[] = [];
  const pinned = sha("1");
  const resolved = await resolvePinnedTree("o", "r", "main", async (path) => {
    calls.push(path);
    if (path.endsWith("/commits/main")) return {sha: pinned};
    if (path.endsWith(`/${pinned}?recursive=1`)) return {truncated: false, tree: [blob("a.jpg", "a")]};
    throw new Error(`unexpected ${path}`);
  });
  assert.equal(resolved.commit, pinned);
  assert.deepEqual(calls, ["/repos/o/r/commits/main", `/repos/o/r/git/trees/${pinned}?recursive=1`]);

  calls.length = 0;
  const fallback = await resolvePinnedTree("o", "r", "main", async (path) => {
    calls.push(path);
    if (path.endsWith("/commits/main")) return {sha: pinned};
    if (path.endsWith(`/${pinned}?recursive=1`)) throw new GithubApiError(500, "server error");
    if (path.endsWith(`/${pinned}`)) return {truncated: false, tree: [treeEntry("dir", "b")]};
    if (path.endsWith(`/${sha("b")}`)) return {truncated: false, tree: [blob("a.jpg", "a")]};
    throw new Error(`unexpected ${path}`);
  });
  assert.equal(fallback.commit, pinned);
  assert.deepEqual(calls, ["/repos/o/r/commits/main", `/repos/o/r/git/trees/${pinned}?recursive=1`,
    `/repos/o/r/git/trees/${pinned}`, `/repos/o/r/git/trees/${sha("b")}`]);
});

test("a dry-run recursive inventory authorizes the same pinned assets after fallback listing", async () => {
  const owner = "hash";
  const repo = "walls";
  const pinned = sha("1");
  const options: MigrationOptions = {apply: false, allowReviewedLegacy: false, owner, repo, commit: pinned};
  const wall: MigrationWall = {docPath: "walls/canonical", incarnation: 1, incarnationNanos: 1_000_000,
    data: {id: "wall_1", review: true,
      wallpaper_url: `https://raw.githubusercontent.com/${owner}/${repo}/main/original.jpg`,
      wallpaper_thumb: `https://raw.githubusercontent.com/${owner}/${repo}/main/thumb_original.jpg`}};
  const makeFetch = (recursiveFails: boolean) => async (path: string): Promise<unknown> => {
    if (path.endsWith(`/commits/${pinned}`)) return {sha: pinned};
    if (path.endsWith(`/${pinned}?recursive=1`)) {
      if (recursiveFails) throw new GithubApiError(500, "server error");
      return {truncated: false, tree: [blob("original.jpg", "a", 20), blob("thumb_original.jpg", "b", 9),
        blob("orphan.jpg", "c", 3)]};
    }
    if (path.endsWith(`/${pinned}`)) {
      return {truncated: false, tree: [blob("original.jpg", "a", 20),
        blob("thumb_original.jpg", "b", 9), blob("orphan.jpg", "c", 3)]};
    }
    throw new Error(`unexpected ${path}`);
  };
  validateMigrationCommit(pinned, false);
  const dryResolved = await resolvePinnedTree(owner, repo, pinned, makeFetch(false));
  validateMigrationCommit(dryResolved.commit, false);
  const dryInventory = buildGithubInventory([wall], dryResolved.tree, options);
  const reviewed = {mode: "dry-run", policy: {allowReviewedLegacy: false}, inventory: createInventoryReport(dryInventory)};

  validateMigrationCommit(pinned, true);
  const applyResolved = await resolvePinnedTree(owner, repo, pinned, makeFetch(true));
  validateMigrationCommit(applyResolved.commit, true);
  const applyInventory = buildGithubInventory([wall], applyResolved.tree, {...options, apply: true});
  const authorized = await validateReviewedInventory(reviewed, applyInventory, applyResolved.commit, false);
  assert.deepEqual([...authorized], ["walls/canonical"]);
  assert.deepEqual(applyInventory.assets.map(({path, url}) => [path, url]), [
    ["original.jpg", `https://raw.githubusercontent.com/${owner}/${repo}/${pinned}/original.jpg`],
    ["thumb_original.jpg", `https://raw.githubusercontent.com/${owner}/${repo}/${pinned}/thumb_original.jpg`],
  ]);
});
