import assert from "node:assert/strict";
import test from "node:test";

import {isAllowedRepo, isValidGithubPath} from "../githubContent";

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
