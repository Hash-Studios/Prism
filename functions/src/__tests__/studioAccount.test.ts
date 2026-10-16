import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {
  STARTER_PACK_KEY,
  STUDIO_ACCOUNT,
  addToStarterPack,
  parseRankArg,
  setupStudioAccount,
  starterPackOrder,
  withStarterPackEntry,
} from "../studio/account";
import {type Doc, installFakeDb} from "./fakeDb";

type Template = admin.remoteConfig.RemoteConfigTemplate;
const STUDIO = {email: STUDIO_ACCOUNT.email, rank: 0};
const NOW = new Date("2026-10-15T10:00:00Z");
const CUSTOM_IDENTITY = {by: "Studio", email: STUDIO_ACCOUNT.email, userPhoto: "https://x.com/new.png"};
const PACK = JSON.stringify([{email: "a@x.com", rank: 1}, {email: "b@x.com", rank: 2}, {email: "c@x.com", rank: 3}]);

function template(parameters: Template["parameters"] = {}, groups: Template["parameterGroups"] = {}): Template {
  return {conditions: [], parameters, parameterGroups: groups, etag: "e1", version: undefined} as unknown as Template;
}

const studioWalls = (n: number): Record<string, Doc> => Object.fromEntries(Array.from({length: n}, (_, i) =>
  [`walls/s${i}`, {email: STUDIO_ACCOUNT.email, review: true}]));

function mockRemoteConfig(t: TestContext, current: Template) {
  const published: Template[] = [];
  const rc = admin.remoteConfig();
  t.mock.method(rc, "getTemplate", async () => current);
  t.mock.method(rc, "validateTemplate", async (next: Template) => next);
  t.mock.method(rc, "publishTemplate", async (next: Template) => {
    published.push(next);
    return next;
  });
  return published;
}

test("withStarterPackEntry adds, re-ranks, or leaves the list", () => {
  assert.deepEqual(JSON.parse(withStarterPackEntry(PACK, STUDIO) as string).at(-1), STUDIO);
  assert.equal(withStarterPackEntry("", STUDIO), JSON.stringify([STUDIO]));
  const moved = withStarterPackEntry(JSON.stringify([{email: STUDIO.email, rank: 5, note: "x"}]), STUDIO);
  assert.deepEqual(JSON.parse(moved as string), [{email: STUDIO.email, rank: 0, note: "x"}]);
  assert.equal(withStarterPackEntry(JSON.stringify([STUDIO]), STUDIO), null);
  assert.throws(() => withStarterPackEntry("{\"email\": \"a\"}", STUDIO), /not a JSON list/);
});

test("addToStarterPack changes the default and explicit condition values only", () => {
  const t = template({
    [STARTER_PACK_KEY]: {
      defaultValue: {value: PACK},
      conditionalValues: {ios: {value: "[]"}, old: {useInAppDefault: true}},
    },
  });
  assert.deepEqual(addToStarterPack(t, STUDIO), ["default", "condition \"ios\""]);
  const parameter = t.parameters[STARTER_PACK_KEY];
  assert.equal((parameter.conditionalValues?.ios as {value: string}).value, JSON.stringify([STUDIO]));
  assert.deepEqual(parameter.conditionalValues?.old, {useInAppDefault: true});
  assert.deepEqual(addToStarterPack(t, STUDIO), []);
});

test("addToStarterPack finds the parameter in a group and adds a missing one", () => {
  const grouped = template({}, {onboarding: {parameters: {[STARTER_PACK_KEY]: {defaultValue: {useInAppDefault: true}}}}});
  assert.deepEqual(addToStarterPack(grouped, STUDIO), ["default"]);
  assert.deepEqual(grouped.parameterGroups.onboarding.parameters[STARTER_PACK_KEY].defaultValue,
    {value: JSON.stringify([STUDIO])});
  assert.equal(grouped.parameters[STARTER_PACK_KEY], undefined);

  const empty = template();
  assert.deepEqual(addToStarterPack(empty, STUDIO), ["default"]);
  assert.deepEqual(empty.parameters[STARTER_PACK_KEY], {valueType: "JSON", defaultValue: {value: JSON.stringify([STUDIO])}});
});

test("starterPackOrder shows which creators onboarding ticks", () => {
  assert.equal(starterPackOrder(withStarterPackEntry(PACK, STUDIO) as string),
    `${STUDIO.email} (0), a@x.com (1), b@x.com (2) ticked; c@x.com (3) listed`);
  assert.equal(starterPackOrder(JSON.stringify([STUDIO])), `${STUDIO.email} (0) ticked`);
});

test("parseRankArg uses 0 without the flag and rejects an operand that is not a whole number", () => {
  assert.equal(parseRankArg(["node", "x", "--apply"]), 0);
  assert.equal(parseRankArg(["node", "x", "--rank", "4"]), 4);
  assert.equal(parseRankArg(["node", "x", "--rank", "-1"]), -1);
  for (const bad of [[], [""], [" "], ["--apply"], ["1.5"], ["1e2"], ["x"]]) {
    assert.throws(() => parseRankArg(["node", "x", "--rank", ...bad]), /whole number/, JSON.stringify(bad));
  }
});

test("a dry run writes nothing", async (t) => {
  const store = installFakeDb(t, studioWalls(5));
  const published = mockRemoteConfig(t, template({[STARTER_PACK_KEY]: {defaultValue: {value: PACK}}}));
  const log = await setupStudioAccount({apply: false, rank: 0, now: NOW});
  assert.equal(log.length, 3);
  assert.match(log[2], /add Studio at rank 0 to the default value/);
  assert.equal(store.has("usersv2/prism-studio"), false);
  assert.equal(store.has("studioConfig/current"), false);
  assert.equal(published.length, 0);
});

test("apply creates the profile and config and skips the starter pack without 5 live walls", async (t) => {
  const store = installFakeDb(t, {...studioWalls(4), "walls/pending": {email: STUDIO_ACCOUNT.email, review: false}});
  const published = mockRemoteConfig(t, template());
  const log = await setupStudioAccount({apply: true, rank: 0, now: NOW});

  const profile = store.get("usersv2/prism-studio");
  assert.equal(profile?.email, STUDIO_ACCOUNT.email);
  assert.equal(profile?.username, "PrismStudio");
  assert.equal(profile?.createdAt, NOW.toISOString());
  assert.deepEqual(profile?.followers, []);
  assert.deepEqual(store.get("studioConfig/current"), {
    generationEnabled: false,
    identity: {by: "Prism Studio", email: STUDIO_ACCOUNT.email, userPhoto: STUDIO_ACCOUNT.profilePhoto},
  });
  assert.match(log[2], /skipped. Studio has 4 live walls/);
  assert.equal(published.length, 0);
});

test("apply adds Studio to the starter pack once it has 5 live walls, and a second run changes nothing", async (t) => {
  const current = template({[STARTER_PACK_KEY]: {defaultValue: {value: PACK}}});
  const store = installFakeDb(t, {
    ...studioWalls(5),
    "studioConfig/current": {generationEnabled: true, model: "m", identity: CUSTOM_IDENTITY},
  });
  const published = mockRemoteConfig(t, current);
  await setupStudioAccount({apply: true, rank: 0, now: NOW});

  assert.equal(published.length, 1);
  const value = published[0].parameters[STARTER_PACK_KEY].defaultValue as {value: string};
  assert.deepEqual(JSON.parse(value.value).at(-1), STUDIO);
  assert.deepEqual(store.get("studioConfig/current"), {generationEnabled: true, model: "m", identity: CUSTOM_IDENTITY});

  const again = await setupStudioAccount({apply: true, rank: 0, now: NOW});
  assert.deepEqual(again, [
    "Profile: usersv2/prism-studio exists.",
    "Config: studioConfig/current has the identity.",
    "Starter pack: has Studio at rank 0.",
  ]);
  assert.equal(published.length, 1);
});

test("apply fills only the empty identity fields and keeps the other config fields", async (t) => {
  const store = installFakeDb(t, {
    "usersv2/prism-studio": {email: STUDIO_ACCOUNT.email},
    "studioConfig/current": {generationEnabled: true, model: "m", identity: {by: "Studio", email: STUDIO_ACCOUNT.email}},
  });
  const log = await setupStudioAccount({apply: true, rank: 0, now: NOW});
  assert.equal(log[1], "Config: set userPhoto of the identity in studioConfig/current.");
  assert.deepEqual(store.get("studioConfig/current"), {
    generationEnabled: true,
    model: "m",
    identity: {by: "Studio", email: STUDIO_ACCOUNT.email, userPhoto: STUDIO_ACCOUNT.profilePhoto},
  });
});

test("an existing config for another email stops the run before any write", async (t) => {
  const store = installFakeDb(t, {"studioConfig/current": {identity: {email: "me@x.com"}}});
  await assert.rejects(setupStudioAccount({apply: true, rank: 0, now: NOW}), /posts as me@x.com/);
  assert.equal(store.has("usersv2/prism-studio"), false);
});
