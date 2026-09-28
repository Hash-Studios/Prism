import assert from "node:assert/strict";
import test from "node:test";

import {canDeleteUpload, isAllowedRepo, isValidGithubPath} from "../githubContent";

const env = {GH_REPO_WALLS: "walls", GH_REPO_SETUPS: "setups"};

test("allows configured repositories only", () => {
  assert.equal(isAllowedRepo("walls", env), true);
  assert.equal(isAllowedRepo("other", env), false);
  assert.equal(isAllowedRepo("owner/walls", env), false);
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
