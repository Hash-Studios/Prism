import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import test from "node:test";
import {TOPICS} from "../topicDigest";

const root = process.env.PRISM_REPO_ROOT ?? join(__dirname, "../../..");
const read = (path: string) => readFileSync(join(root, path), "utf8");
const quoted = (text: string) => [...text.matchAll(/'([^']+)'/g)].map((m) => m[1]).sort();
const serverKeys = [...TOPICS.keys()].sort();

test("the rules accept exactly the server's topic keys", () => {
  const rule = read("firestore.rules").match(/followedTopics\.hasOnly\(\[([^\]]+)\]\)/);
  assert.ok(rule, "validTopicSession lists the keys");
  assert.deepEqual(quoted(rule[1]), serverKeys);
});

test("the app follows exactly the server's categories and moods", () => {
  const categories = read("lib/data/categories/category_definition.dart")
    .match(/prismClassifierCategories = <String>\{([^}]+)\}/);
  const moods = [...read("lib/features/moods/domain/entities/wall_mood.dart").matchAll(/^\s+\w+\('([a-z_]+)'/gm)];
  assert.ok(categories, "prismClassifierCategories is found");
  const appKeys = [...quoted(categories[1]).map((name) => `category:${name}`), ...moods.map((m) => `mood:${m[1]}`)];
  assert.deepEqual(appKeys.sort(), serverKeys);
  assert.equal(serverKeys.length, 27);
});
