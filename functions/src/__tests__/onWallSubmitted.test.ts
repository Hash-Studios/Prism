import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import * as admin from "firebase-admin";
import {isGithubRawUrl, onWallSubmitted} from "../onWallSubmitted";
import {type Doc, installFakeDb} from "./fakeDb";

const RAW = "https://raw.githubusercontent.com/owner/walls/main";

function setup(t: TestContext, owner: Doc | null, wall: Doc) {
  const store = installFakeDb(t, {
    "walls/w1": wall,
    ...(owner ? {"usersv2/maker": {email: "maker@example.com", ...owner}} : {}),
    "config/adminNotifications": {emails: ["admin@example.com"]},
    "usersv2/adm1": {email: "admin@example.com"},
  });
  const topics: string[] = [];
  t.mock.method(admin.messaging(), "send", async (message: {topic?: string}) => {
    topics.push(message.topic ?? "");
    return "id";
  });
  return {store, topics};
}

const fire = (store: Map<string, Doc>) => onWallSubmitted.run({
  params: {wallId: "w1"},
  data: {
    data: () => store.get("walls/w1"),
    ref: {update: async (update: Doc) => void store.set("walls/w1", {...store.get("walls/w1"), ...update})},
  },
} as unknown as Parameters<typeof onWallSubmitted.run>[0]);

const wall = (extra: Doc = {}): Doc => ({
  email: "maker@example.com", by: "Fake Admin", userPhoto: "https://evil.example/p.png", review: false,
  wallpaper_url: `${RAW}/a.jpg`, wallpaper_thumb: `${RAW}/thumb_a.jpg`, ...extra,
});

test("by and userPhoto are rewritten from the owner's profile", async (t) => {
  const {store} = setup(t, {name: "Real Maker", username: "RealMaker", profilePhoto: "https://p/real.png", premium: true}, wall());
  await fire(store);
  assert.equal(store.get("walls/w1")?.by, "Real Maker");
  assert.equal(store.get("walls/w1")?.userPhoto, "https://p/real.png");
});

test("the username fills in when the profile has no name, and nothing is written when both match", async (t) => {
  const first = setup(t, {username: "RealMaker", profilePhoto: "https://p/real.png"}, wall());
  await fire(first.store);
  assert.equal(first.store.get("walls/w1")?.by, "RealMaker");

  const updates: Doc[] = [];
  const matching = installFakeDb(t, {
    "usersv2/maker": {email: "maker@example.com", name: "Real Maker", profilePhoto: "https://p/real.png"},
  });
  const sameWall = wall({by: "Real Maker", userPhoto: "https://p/real.png"});
  matching.set("walls/w1", sameWall);
  await onWallSubmitted.run({
    params: {wallId: "w1"},
    data: {data: () => sameWall, ref: {update: async (update: Doc) => updates.push(update)}},
  } as unknown as Parameters<typeof onWallSubmitted.run>[0]);
  assert.deepEqual(updates, []);
});

test("a wall of an unknown owner keeps its fields", async (t) => {
  const {store} = setup(t, null, wall());
  await fire(store);
  assert.equal(store.get("walls/w1")?.by, "Fake Admin");
});

test("a premium submission notifies the admins and a free one does not", async (t) => {
  const premium = setup(t, {name: "Maker", premium: true}, wall());
  await fire(premium.store);
  assert.deepEqual(premium.topics, ["u_adm1"]);

  const free = setup(t, {name: "Maker", premium: false}, wall());
  await fire(free.store);
  assert.deepEqual(free.topics, []);
});

test("an image link outside the GitHub raw host is logged and the wall is kept", async (t) => {
  const {store} = setup(t, {name: "Maker", premium: true}, wall({wallpaper_url: "https://evil.example/a.jpg"}));
  await fire(store);
  assert.equal(store.get("walls/w1")?.wallpaper_url, "https://evil.example/a.jpg");
});

test("only https links on raw.githubusercontent.com pass the host check", () => {
  assert.equal(isGithubRawUrl(`${RAW}/a.jpg`), true);
  assert.equal(isGithubRawUrl("http://raw.githubusercontent.com/o/r/m/a.jpg"), false);
  assert.equal(isGithubRawUrl("https://raw.githubusercontent.com.evil.example/a.jpg"), false);
  assert.equal(isGithubRawUrl("https://evil.example/raw.githubusercontent.com/a.jpg"), false);
  assert.equal(isGithubRawUrl("not a url"), false);
  assert.equal(isGithubRawUrl(undefined), false);
});
