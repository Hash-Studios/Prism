import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import test from "node:test";

type Index = {collectionGroup: string; fields: Array<{fieldPath: string; order?: string; arrayConfig?: string}>};
type Override = {collectionGroup: string; fieldPath: string; ttl?: boolean};

const config = JSON.parse(readFileSync(join(__dirname, "../../../firestore.indexes.json"), "utf8")) as {
  indexes: Index[];
  fieldOverrides: Override[];
};

test("walls have the tag search index: tags contains, review, newest first", () => {
  const index = config.indexes.find((i) => i.collectionGroup === "walls" &&
    i.fields[0]?.fieldPath === "tags" && i.fields[0].arrayConfig === "CONTAINS");
  assert.ok(index);
  assert.deepEqual(index.fields.slice(1).map((f) => [f.fieldPath, f.order]), [["review", "ASCENDING"], ["createdAt", "DESCENDING"]]);
});

test("view rate docs expire through a TTL policy on expireAt", () => {
  assert.ok(config.fieldOverrides.some((o) => o.collectionGroup === "viewRate" && o.fieldPath === "expireAt" && o.ttl === true));
});
