import assert from "node:assert/strict";
import test from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";
import {buildWrappedDocs, notifyWrapped, WRAPPED_RUN} from "../scripts/buildWrapped";
import {wrappedDocPath} from "../wrapped";

const NOW = new Date("2026-11-25T12:00:00Z");
const at = (iso: string) => admin.firestore.Timestamp.fromDate(new Date(`${iso}T10:00:00Z`));

async function clear() {
  await Promise.all(["usersv2", "walls", "profiles", "wrapped", "wrappedRuns", "coinTransactions", "aiGenerations",
    "folders", "weeklyChallenges", "notifications"].map((name) => db.recursiveDelete(db.collection(name))));
}

/** heavy: 12 saves and more; light: 10 saves and a 3-day run; quiet: 3 saves; gone: a deleted account. */
async function seed() {
  const batch = db.batch();
  for (let i = 1; i <= 12; i++) {
    batch.set(db.doc(`walls/W${i}`), {id: `W${i}`, review: true, wallpaper_thumb: `https://img/W${i}.jpg`,
      colors: i % 2 ? ["purple", "blue"] : ["blue", "pink"], creatorUid: i <= 4 ? "maya" : `c${i}`,
      category: i <= 6 ? "Nature" : "Space"});
  }
  batch.set(db.doc("profiles/maya"), {username: "maya", name: "Maya", profilePhoto: ""});
  batch.set(db.doc("usersv2/maya"), {email: "maya@example.com"});
  for (const [uid, count] of [["heavy", 12], ["light", 10], ["quiet", 3], ["gone", 12]] as const) {
    batch.set(db.doc(`usersv2/${uid}`), {email: `${uid}@example.com`, ...(uid === "gone" ? {deleted: true} : {}),
      coinState: {streakTimezoneOffsetMinutes: 330}});
    for (let i = 1; i <= count; i++) {
      batch.set(db.doc(`usersv2/${uid}/images/W${i}`), {id: `W${i}`, provider: "Prism", thumb: `https://img/W${i}.jpg`,
        // Saves before 8 Oct carry only createdAt; one older save from 2025 must not count.
        ...(i % 3 ? {favouritedAt: at(`2026-10-1${i % 10}`)} : {createdAt: at(`2026-0${1 + (i % 9)}-15`)})});
    }
  }
  batch.set(db.doc("usersv2/heavy/images/OLD"), {id: "OLD", provider: "Prism", thumb: "x", createdAt: at("2025-12-30")});
  for (const [uid, days] of [["heavy", 6], ["light", 3]] as const) {
    for (let d = 1; d <= days; d++) {
      batch.set(db.doc(`coinTransactions/${uid}_${d}`), {userId: uid, action: "dailyLogin", delta: 5,
        createdAt: at(`2026-04-0${d}`)});
    }
  }
  batch.set(db.doc("aiGenerations/g1"), {userId: "heavy", createdAt: at("2026-06-01"), imageUrl: "https://img/ai.jpg",
    watermarkedImageUrl: "https://img/ai-w.jpg"});
  batch.set(db.doc("folders/f1"), {ownerId: "heavy", createdAt: at("2026-10-28"), covers: ["https://img/f.jpg"]});
  await batch.commit();
}

test("the Wrapped job builds private docs, resumes, stays idempotent and notifies once", {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  await clear();
  await seed();
  const quiet = () => undefined;

  const dry = await buildWrappedDocs(db, {apply: false, now: NOW, log: quiet});
  assert.equal(dry.eligible, 2);
  assert.equal((await db.collection("wrapped").get()).size, 0, "a dry run writes nothing");

  const first = await buildWrappedDocs(db, {apply: true, now: NOW, pageSize: 2, maxPages: 1, log: quiet});
  assert.equal(first.phase, "building");
  assert.equal((await db.doc(WRAPPED_RUN).get()).data()?.cursor, "heavy");
  const rest = await buildWrappedDocs(db, {apply: true, now: new Date("2026-11-30T00:00:00Z"), pageSize: 2, log: quiet});
  assert.equal(rest.phase, "built");
  assert.equal(rest.scanned, 3, "the resumed run starts after the checkpoint");

  const heavy = (await db.doc(wrappedDocPath("heavy")).get()).data();
  assert.ok(heavy);
  assert.equal(heavy.through.toMillis(), NOW.getTime(), "a resumed run keeps the first run's window");
  assert.deepEqual(heavy.cards.map((c: {id: string}) => c.id),
    ["intro", "saves", "colours", "creator", "streak", "ai", "category", "folders", "summary"]);
  assert.equal(heavy.cards[1].value, 12, "the 2025 save is outside the window");
  assert.equal(heavy.cards[3].creator.username, "maya");
  assert.equal(JSON.stringify(heavy).includes("@example.com"), false, "no email in the doc");
  const light = (await db.doc(wrappedDocPath("light")).get()).data();
  assert.deepEqual(light?.cards.map((c: {id: string}) => c.id),
    ["intro", "saves", "colours", "creator", "streak", "category", "summary"]);
  assert.equal((await db.doc(wrappedDocPath("quiet")).get()).exists, false);
  assert.equal((await db.doc(wrappedDocPath("gone")).get()).exists, false);
  assert.deepEqual((await db.collection("wrapped").listDocuments()).map((d) => d.id).sort(), ["heavy", "light"]);

  const again = await buildWrappedDocs(db, {apply: true, now: NOW, log: quiet});
  assert.equal(again.phase, "built", "a finished build does nothing without --restart");

  const sent: string[] = [];
  const send = async (_payload: unknown, recipient: {uid?: string}) => {
    sent.push(recipient.uid ?? "");
    return true;
  };
  await notifyWrapped(db, {apply: true, send, log: quiet});
  assert.deepEqual(sent.sort(), ["heavy", "light"]);
  await notifyWrapped(db, {apply: true, send, log: quiet});
  assert.equal(sent.length, 2, "a second notify run sends nothing");
  await db.doc(WRAPPED_RUN).update({phase: "building"});
  await assert.rejects(() => notifyWrapped(db, {apply: true, send, log: quiet}), /Finish the build/);
  await db.doc(WRAPPED_RUN).update({phase: "built"});

  await db.doc("usersv2/light/images/W1").delete();
  await db.doc("usersv2/light/images/W2").delete();
  const rebuilt = await buildWrappedDocs(db, {apply: true, restart: true, now: NOW, log: quiet});
  assert.equal(rebuilt.removed, 1, "a restart removes a doc whose owner is no longer eligible");
  assert.equal((await db.doc(wrappedDocPath("light")).get()).exists, false);
  assert.ok((await db.doc(wrappedDocPath("heavy")).get()).data()?.notifiedAt, "a rebuild keeps notifiedAt");
  await clear();
});
