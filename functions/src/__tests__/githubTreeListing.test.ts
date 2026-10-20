import assert from "node:assert/strict";
import {test} from "node:test";
import {GithubApiError, listGithubTree} from "../scripts/migrateGithubToR2";

const sha = (c: string) => c.repeat(40);
const blob = (path: string, c: string) => ({path, type: "blob", sha: sha(c), size: 10});

test("uses the recursive tree when GitHub returns it", async () => {
  const calls: string[] = [];
  const tree = await listGithubTree(async (path) => {
    calls.push(path);
    return {truncated: false, tree: [blob("a.jpg", "a"), {path: "dir", type: "tree", sha: sha("b")}, blob("dir/b.jpg", "c")]};
  }, "/repos/o/r", sha("f"));
  assert.deepEqual(calls, [`/repos/o/r/git/trees/${sha("f")}?recursive=1`]);
  assert.deepEqual(tree.entries.map((e) => e.path), ["a.jpg", "dir", "dir/b.jpg"]);
  assert.equal(tree.truncated, false);
});

test("walks the tree level by level when the recursive call fails with a server error", async () => {
  const calls: string[] = [];
  const tree = await listGithubTree(async (path) => {
    calls.push(path);
    if (path.endsWith("?recursive=1")) throw new GithubApiError(500, "GitHub API failed (500)");
    if (path.endsWith(sha("f"))) return {truncated: false, tree: [blob("a.jpg", "a"), {path: "dir", type: "tree", sha: sha("b")}]};
    if (path.endsWith(sha("b"))) return {truncated: false, tree: [blob("b.jpg", "c")]};
    throw new Error(`unexpected ${path}`);
  }, "/repos/o/r", sha("f"));
  assert.deepEqual(tree.entries.map((e) => [e.path, e.type, e.sha]), [
    ["a.jpg", "blob", sha("a")], ["dir", "tree", sha("b")], ["dir/b.jpg", "blob", sha("c")],
  ]);
  assert.equal(tree.truncated, false);
  assert.equal(calls.length, 3);
});

test("a truncated level in the fallback marks the whole tree truncated", async () => {
  const tree = await listGithubTree(async (path) => {
    if (path.endsWith("?recursive=1")) throw new GithubApiError(502, "GitHub API failed (502)");
    return {truncated: true, tree: [blob("a.jpg", "a")]};
  }, "/repos/o/r", sha("f"));
  assert.equal(tree.truncated, true);
});

test("a client error from the recursive call is not retried level by level", async () => {
  let calls = 0;
  await assert.rejects(listGithubTree(async () => {
    calls += 1;
    throw new GithubApiError(404, "GitHub API failed (404)");
  }, "/repos/o/r", sha("f")), /404/);
  assert.equal(calls, 1);
});

test("the fallback still rejects unsafe entry names", async () => {
  await assert.rejects(listGithubTree(async (path) => {
    if (path.endsWith("?recursive=1")) throw new GithubApiError(500, "GitHub API failed (500)");
    return {truncated: false, tree: [blob("..", "a")]};
  }, "/repos/o/r", sha("f")), /invalid/);
});
