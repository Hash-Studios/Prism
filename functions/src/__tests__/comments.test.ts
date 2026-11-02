import assert from "node:assert/strict";
import test, {type TestContext} from "node:test";
import {type AddCommentResponse, addComment, commentIdFor, commentIo, commentText, deleteComment, parseCommentTarget,
  removeCommentsForAccount, setCommentHidden, setCommentState} from "../comments";
import {nativeNotificationLocalization, renderNotificationCopy} from "../notificationCatalog";
import {type Doc, installFakeDb} from "./fakeDb";

const NOW = new Date("2026-11-02T12:00:00Z");
const DAY = 86_400_000;
const REQ = "request_0001";
const FAN_COMMENT = commentIdFor("fan", REQ);
const HEX = "0123456789abcdef0123456789abcdef";

type Sent = {
  payload: {message: {kind: string}; data: Record<string, string>; modifier: string; title: string; body: string};
  recipient: {uid: string};
  pushEnabled: boolean;
};

function setup(t: TestContext, seed: Record<string, Doc> = {}, now = NOW) {
  t.mock.timers.enable({apis: ["Date"], now});
  t.mock.method(commentIo, "account", async () => ({createdMs: now.getTime() - 2 * DAY, member: true}));
  t.mock.method(commentIo, "enabled", async () => true);
  const sent: Sent[] = [];
  t.mock.method(commentIo, "notify", async (payload: Sent["payload"], recipient: Sent["recipient"], pushEnabled: boolean) => {
    sent.push({payload, recipient, pushEnabled});
    return true;
  });
  const store = installFakeDb(t, {
    "usersv2/fan": {name: "Ava", username: "ava", profilePhoto: "p.png"},
    "usersv2/fan2": {name: "Ben", username: "ben", profilePhoto: "b.png"},
    "usersv2/maker": {email: "maker@example.com", name: "Maker"},
    "walls/w1": {id: "NEON", creatorUid: "maker", review: true, title: "Neon rain"},
    "walls/draft": {id: "D1", creatorUid: "maker", review: false},
    ...seed,
  });
  return {store, sent};
}

const body = (extra: Record<string, unknown> = {}) => ({wallId: "w1", requestId: REQ, text: "nice one", ...extra});
const add = (data: Record<string, unknown>, uid = "fan"): Promise<AddCommentResponse> =>
  addComment.run({auth: {uid, token: {}}, data} as never);
const count = (store: Map<string, Doc>, wallId = "NEON") => store.get(`wallpaper_stats/${wallId}`)?.comments ?? 0;
const commentPaths = (store: Map<string, Doc>) => [...store.keys()].filter((k) => k.includes("/comments/"));
const adminAuth = (uid: string) => ({auth: {uid, token: {admin: true}}});

test("addComment refuses a caller who is not signed in", async (t) => {
  const {store} = setup(t);
  await assert.rejects(addComment.run({data: body()} as never), {code: "unauthenticated"});
  assert.deepEqual(commentPaths(store), []);
});

test("addComment rejects a bad wallId, requestId or text type with invalid-argument", async (t) => {
  const {store} = setup(t);
  for (const bad of [{wallId: "a/b"}, {wallId: ""}, {requestId: "x"}, {text: 7}]) {
    await assert.rejects(add(body(bad)), {code: "invalid-argument"}, JSON.stringify(bad));
  }
  assert.deepEqual(commentPaths(store), []);
  assert.equal(count(store), 0);
});

test("a guest account cannot comment", async (t) => {
  const {store} = setup(t);
  t.mock.method(commentIo, "account", async () => ({createdMs: NOW.getTime() - 2 * DAY, member: false}));
  assert.deepEqual(await add(body()), {ok: false, reason: "comment_guest"});
  assert.deepEqual(commentPaths(store), []);
  assert.equal(count(store), 0);
});

test("a deleted profile cannot comment", async (t) => {
  const {store} = setup(t, {"usersv2/fan": {name: "Ava", username: "ava", deleted: true}});
  assert.deepEqual(await add(body()), {ok: false, reason: "comment_guest"});
  assert.deepEqual(commentPaths(store), []);
  assert.equal(count(store), 0);
});

test("an account younger than 24 hours cannot comment", async (t) => {
  const {store} = setup(t);
  t.mock.method(commentIo, "account", async () => ({createdMs: NOW.getTime() - DAY + 1, member: true}));
  assert.deepEqual(await add(body()), {ok: false, reason: "comment_too_new"});
  assert.deepEqual(commentPaths(store), []);
});

test("an account exactly 24 hours old can comment", async (t) => {
  setup(t);
  t.mock.method(commentIo, "account", async () => ({createdMs: NOW.getTime() - DAY, member: true}));
  const res = await add(body());
  assert.equal(res.ok, true);
});

test("a draft or missing wall cannot be commented on", async (t) => {
  const {store} = setup(t);
  assert.deepEqual(await add(body({wallId: "draft"})), {ok: false, reason: "comment_wall_unavailable"});
  assert.deepEqual(await add(body({wallId: "nope"})), {ok: false, reason: "comment_wall_unavailable"});
  assert.deepEqual(commentPaths(store), []);
});

test("blank text is refused as empty", async (t) => {
  const {store} = setup(t);
  assert.deepEqual(await add(body({text: ""})), {ok: false, reason: "comment_empty"});
  assert.deepEqual(await add(body({text: "   \n  "})), {ok: false, reason: "comment_empty"});
  assert.deepEqual(commentPaths(store), []);
});

test("500 graphemes is allowed", async (t) => {
  const {store} = setup(t);
  const res = await add(body({text: "a".repeat(500)}));
  assert.equal(res.ok, true);
  assert.equal(count(store), 1);
});

test("501 graphemes is too long", async (t) => {
  const {store} = setup(t);
  assert.deepEqual(await add(body({text: "a".repeat(501)})), {ok: false, reason: "comment_too_long"});
  assert.deepEqual(commentPaths(store), []);
});

test("length counts graphemes, so 500 skin-toned emoji are allowed and 501 are not", async (t) => {
  const {store} = setup(t);
  assert.equal((await add(body({text: "👍🏽".repeat(500)}))).ok, true);
  assert.equal(count(store), 1);
  assert.deepEqual(await add(body({requestId: "request_0002", text: "👍🏽".repeat(501)})),
    {ok: false, reason: "comment_too_long"});
});

test("hidden or bidi control characters are refused", async (t) => {
  const {store} = setup(t);
  for (const text of ["hi​there", "a‮b", "x\u0007"]) {
    assert.deepEqual(await add(body({text})), {ok: false, reason: "comment_hidden_characters"}, JSON.stringify(text));
  }
  assert.deepEqual(commentPaths(store), []);
});

test("a line break and a ZWJ emoji sequence are allowed", async (t) => {
  setup(t);
  assert.equal((await add(body({text: "line one\nline two"}))).ok, true);
  t.mock.timers.tick(10_000);
  assert.equal((await add(body({requestId: "request_0002", text: "\u{1F469}‍\u{1F4BB} nice"}))).ok, true);
});

test("a blocked word is refused, including a leet spelling", async (t) => {
  const {store} = setup(t);
  assert.deepEqual(await add(body({text: "you are a r3tard"})), {ok: false, reason: "comment_blocked_word"});
  assert.deepEqual(commentPaths(store), []);
});

test("a creator who blocked the commenter refuses the comment", async (t) => {
  const {store} = setup(t, {"usersv2/maker/blockedUsers/fan": {blockedAt: 1}});
  assert.deepEqual(await add(body()), {ok: false, reason: "comment_blocked"});
  assert.deepEqual(commentPaths(store), []);
});

test("a commenter who blocked the creator refuses the comment", async (t) => {
  const {store} = setup(t, {"usersv2/fan/blockedUsers/maker": {blockedAt: 1}});
  assert.deepEqual(await add(body()), {ok: false, reason: "comment_blocked"});
  assert.deepEqual(commentPaths(store), []);
});

test("a second comment within 10 seconds is too fast, and 10 seconds later it is allowed", async (t) => {
  const {store} = setup(t);
  assert.equal((await add(body())).ok, true);
  t.mock.timers.tick(9_999);
  assert.deepEqual(await add(body({requestId: "request_0002"})), {ok: false, reason: "comment_too_fast"});
  assert.equal(count(store), 1);
  t.mock.timers.tick(1);
  assert.equal((await add(body({requestId: "request_0002"}))).ok, true);
  assert.equal(count(store), 2);
});

test("50 comments in one UTC day are allowed, the 51st is refused, and the next UTC day works again", async (t) => {
  const {store} = setup(t);
  for (let i = 0; i < 50; i++) {
    if (i > 0) t.mock.timers.tick(10_000);
    const res = await add(body({requestId: `request_${String(i).padStart(4, "0")}`}));
    assert.equal(res.ok, true, `comment ${i}`);
  }
  t.mock.timers.tick(10_000);
  assert.deepEqual(await add(body({requestId: "request_0050"})), {ok: false, reason: "comment_daily_limit"});
  assert.equal(count(store), 50);
  t.mock.timers.tick(DAY);
  assert.equal((await add(body({requestId: "request_0051"}))).ok, true);
  assert.equal(count(store), 51);
});

test("the kill switch refuses comments and writes nothing", async (t) => {
  const {store} = setup(t);
  t.mock.method(commentIo, "enabled", async () => false);
  assert.deepEqual(await add(body()), {ok: false, reason: "comments_disabled"});
  assert.deepEqual(commentPaths(store), []);
  assert.equal(count(store), 0);
});

test("a successful comment is returned, stored visibly and counted", async (t) => {
  const {store} = setup(t);
  assert.deepEqual(await add(body()), {
    ok: true,
    comment: {
      id: FAN_COMMENT,
      wallId: "w1",
      authorUid: "fan",
      authorName: "Ava",
      authorUsername: "ava",
      authorPhoto: "p.png",
      text: "nice one",
      createdAtMs: NOW.getTime(),
      state: "visible",
    },
  });
  assert.equal(store.get(`walls/w1/comments/${FAN_COMMENT}`)?.state, "visible");
  assert.equal(count(store), 1);
});

test("whitespace is collapsed and the ends trimmed before storing", async (t) => {
  const {store} = setup(t);
  const res = await add(body({text: "  hi   there \n\n\n\n you "}));
  assert.equal(res.ok && res.comment.text, "hi there\n\nyou");
  assert.equal(store.get(`walls/w1/comments/${FAN_COMMENT}`)?.text, "hi there\n\nyou");
});

test("a retry with the same requestId returns the same comment, writes once and does not use the rate limit", async (t) => {
  const {store} = setup(t);
  const first = await add(body());
  t.mock.timers.tick(5_000);
  const again = await add(body());
  assert.deepEqual(again, first);
  assert.equal(commentPaths(store).length, 1);
  assert.equal(count(store), 1);
  assert.equal(store.get("commentRate/fan")?.count, 1);
  t.mock.timers.tick(5_000);
  assert.equal((await add(body({requestId: "request_0002"}))).ok, true);
  assert.equal(count(store), 2);
});

test("the first comment on a wall pushes the creator once, with the wall deep link", async (t) => {
  const {sent} = setup(t);
  assert.equal((await add(body())).ok, true);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].payload.message.kind, "wallCommented");
  assert.deepEqual(sent[0].payload.data, {route: "wall", wall_id: "w1", notification_kind: "wall_comment"});
  assert.equal(sent[0].recipient.uid, "maker");
  assert.equal(sent[0].pushEnabled, true);
});

test("a push waits an hour, so a comment 30 minutes later does not push and one 60 minutes later does", async (t) => {
  const {sent} = setup(t, {"usersv2/fan2": {name: "Ben", username: "ben", profilePhoto: "b.png"}});
  assert.equal((await add(body())).ok, true);
  t.mock.timers.tick(30 * 60_000);
  assert.equal((await add(body({requestId: "request_0002"}), "fan2")).ok, true);
  assert.equal(sent.length, 1);
  t.mock.timers.tick(30 * 60_000);
  assert.equal((await add(body({requestId: "request_0003"}))).ok, true);
  assert.equal(sent.length, 2);
});

test("a creator commenting on their own wall never pushes", async (t) => {
  const {sent, store} = setup(t);
  const res = await add(body(), "maker");
  assert.equal(res.ok, true);
  assert.equal(count(store), 1);
  assert.equal(sent.length, 0);
});

test("the creator's follower-alerts setting is passed to notify as false", async (t) => {
  const {sent} = setup(t, {"usersv2/maker/private/session": {followerAlerts: false}});
  assert.equal((await add(body())).ok, true);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].pushEnabled, false);
});

test("the author can delete their comment and the count drops", async (t) => {
  const {store} = setup(t);
  await add(body());
  assert.deepEqual(await deleteComment.run({auth: {uid: "fan", token: {}}, data: {wallId: "w1", commentId: FAN_COMMENT}} as never),
    {ok: true, deleted: true, role: "author"});
  assert.equal(store.get(`walls/w1/comments/${FAN_COMMENT}`), undefined);
  assert.equal(count(store), 0);
});

test("the wall creator can delete a comment and is recorded as creator", async (t) => {
  setup(t);
  await add(body());
  assert.deepEqual(await deleteComment.run({auth: {uid: "maker", token: {}}, data: {wallId: "w1", commentId: FAN_COMMENT}} as never),
    {ok: true, deleted: true, role: "creator"});
});

test("an admin can delete a comment and is recorded as admin", async (t) => {
  setup(t);
  await add(body());
  assert.deepEqual(await deleteComment.run({...adminAuth("boss"), data: {wallId: "w1", commentId: FAN_COMMENT}} as never),
    {ok: true, deleted: true, role: "admin"});
});

test("another user cannot delete a comment, and it stays", async (t) => {
  const {store} = setup(t);
  await add(body());
  await assert.rejects(
    deleteComment.run({auth: {uid: "fan2", token: {}}, data: {wallId: "w1", commentId: FAN_COMMENT}} as never),
    {code: "permission-denied"},
  );
  assert.equal(store.get(`walls/w1/comments/${FAN_COMMENT}`)?.state, "visible");
  assert.equal(count(store), 1);
});

test("deleting a missing comment returns deleted false with no role", async (t) => {
  setup(t);
  assert.deepEqual(await deleteComment.run({auth: {uid: "fan", token: {}}, data: {wallId: "w1", commentId: HEX}} as never),
    {ok: true, deleted: false, role: ""});
});

test("hiding a visible comment takes it off the count, and hiding it again changes nothing", async (t) => {
  const {store} = setup(t);
  await add(body());
  assert.equal(await setCommentState("w1", FAN_COMMENT, "hidden", "reports"), true);
  assert.equal(store.get(`walls/w1/comments/${FAN_COMMENT}`)?.state, "hidden");
  assert.equal(count(store), 0);
  assert.equal(await setCommentState("w1", FAN_COMMENT, "hidden", "reports"), false);
  assert.equal(count(store), 0);
});

test("deleting a hidden comment does not change the count", async (t) => {
  const {store} = setup(t);
  await add(body());
  await setCommentState("w1", FAN_COMMENT, "hidden", "reports");
  await deleteComment.run({auth: {uid: "fan", token: {}}, data: {wallId: "w1", commentId: FAN_COMMENT}} as never);
  assert.equal(count(store), 0);
});

test("showing a hidden comment again adds it back to the count", async (t) => {
  const {store} = setup(t);
  await add(body());
  await setCommentState("w1", FAN_COMMENT, "hidden", "reports");
  assert.equal(await setCommentState("w1", FAN_COMMENT, "visible", "boss"), true);
  assert.equal(store.get(`walls/w1/comments/${FAN_COMMENT}`)?.state, "visible");
  assert.equal(count(store), 1);
});

test("setCommentHidden refuses a non-admin with permission-denied", async (t) => {
  const {store} = setup(t);
  await add(body());
  await assert.rejects(
    setCommentHidden.run({auth: {uid: "fan", token: {}}, data: {wallId: "w1", commentId: FAN_COMMENT, hidden: true}} as never),
    {code: "permission-denied"},
  );
  assert.equal(count(store), 1);
});

test("an admin can hide a comment and show it again", async (t) => {
  const {store} = setup(t);
  await add(body());
  assert.deepEqual(await setCommentHidden.run({...adminAuth("boss"),
    data: {wallId: "w1", commentId: FAN_COMMENT, hidden: true}} as never), {ok: true, changed: true});
  assert.equal(count(store), 0);
  assert.deepEqual(await setCommentHidden.run({...adminAuth("boss"),
    data: {wallId: "w1", commentId: FAN_COMMENT, hidden: false}} as never), {ok: true, changed: true});
  assert.equal(store.get(`walls/w1/comments/${FAN_COMMENT}`)?.state, "visible");
  assert.equal(count(store), 1);
});

test("removeCommentsForAccount deletes every comment by the account and counts only its visible ones", async (t) => {
  const {store} = setup(t, {
    "walls/w2": {id: "W2", creatorUid: "maker", review: true, title: "Second"},
  });
  await add(body({requestId: "request_0001"}));
  t.mock.timers.tick(10_000);
  await add(body({wallId: "w2", requestId: "request_0002"}));
  t.mock.timers.tick(10_000);
  await add(body({requestId: "request_0003"}));
  t.mock.timers.tick(10_000);
  const hiddenId = commentIdFor("fan", "request_0004");
  await add(body({requestId: "request_0004"}));
  await setCommentState("w1", hiddenId, "hidden", "reports");
  t.mock.timers.tick(10_000);
  await add(body({requestId: "request_0005"}), "fan2");
  assert.equal(count(store), 3);
  assert.equal(count(store, "W2"), 1);

  await removeCommentsForAccount("fan");
  assert.equal(count(store), 1);
  assert.equal(count(store, "W2"), 0);
  assert.deepEqual(commentPaths(store).sort(), [`walls/w1/comments/${commentIdFor("fan2", "request_0005")}`]);

  await removeCommentsForAccount("fan");
  assert.equal(count(store), 1);
  assert.equal(count(store, "W2"), 0);
  assert.equal(commentPaths(store).length, 1);
});

test("parseCommentTarget splits a wall id and a 32-hex comment id", () => {
  assert.deepEqual(parseCommentTarget(`w1:${HEX}`), {wallId: "w1", commentId: HEX});
  assert.equal(parseCommentTarget("w1"), null);
  assert.equal(parseCommentTarget(`:${HEX}`), null);
  assert.equal(parseCommentTarget(`a/b:${HEX}`), null);
  assert.equal(parseCommentTarget("w1:XYZ"), null);
  assert.deepEqual(parseCommentTarget(`a:b:${HEX}`), {wallId: "a:b", commentId: HEX});
});

test("commentText refuses non-string input by throwing invalid-argument", () => {
  assert.throws(() => commentText(7), {code: "invalid-argument"});
});

test("the wallCommented push copy names the commenter and the wall", () => {
  const copy = {kind: "wallCommented" as const, commenterName: "Ava", wallTitle: "Neon rain", text: "love it"};
  const rendered = renderNotificationCopy(copy);
  assert.equal(rendered.title, "Ava commented on Neon rain");
  assert.equal(rendered.body, "love it");
  assert.equal(renderNotificationCopy({...copy, wallTitle: ""}).title, "Ava commented on your wall");
  assert.deepEqual(nativeNotificationLocalization(rendered), {
    titleKey: "notif_push_wall_commented_title",
    titleArgs: ["Ava", "Neon rain"],
    bodyKey: "notif_push_wall_commented_body",
    bodyArgs: ["love it"],
  });
  assert.equal(nativeNotificationLocalization(renderNotificationCopy({...copy, wallTitle: ""}))?.titleKey,
    "notif_push_wall_commented_title_untitled");
});
