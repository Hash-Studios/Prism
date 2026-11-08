import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import test from "node:test";
import {SMART_KINDS} from "../smartFolders";
import {CATEGORY_NAMES} from "../wallCategory";

// The app keeps copies of the server's smart folder category list and rule kinds in smart_rule.dart.
const DART_FILE = join(__dirname, "..", "..", "..", "lib", "features", "folders", "domain", "entities", "smart_rule.dart");

test("the app's smart category list matches the server's CATEGORY_NAMES", () => {
  const source = readFileSync(DART_FILE, "utf8");
  const block = /const List<String> smartCategoryNames = <String>\[([\s\S]*?)\];/.exec(source);
  assert.ok(block, "smart_rule.dart has no smartCategoryNames list");
  const names = [...block[1].matchAll(/'([^']*)'/g)].map((match) => match[1]);
  assert.deepStrictEqual(names, [...CATEGORY_NAMES]);
});

test("the app's SmartRuleKind wire values match the server's SMART_KINDS", () => {
  const source = readFileSync(DART_FILE, "utf8");
  const block = /enum SmartRuleKind \{([\s\S]*?);/.exec(source);
  assert.ok(block, "smart_rule.dart has no SmartRuleKind enum");
  const wires = [...block[1].matchAll(/^\s*\w+\('(\w+)'/gm)].map((match) => match[1]);
  assert.deepStrictEqual(new Set(wires), new Set(SMART_KINDS));
});
