import assert from "node:assert/strict";
import test, {mock} from "node:test";
import * as admin from "firebase-admin";
import sharp from "sharp";
import {db} from "../common";
import {categorizeWallpaper} from "../categorizeWallpaper";
import {onWallCategorize} from "../onWallCategorize";
import * as wallCategory from "../wallCategory";
import * as wallDepth from "../wallDepth";
import {backfillWallColors, parseBackfillArgs} from "../scripts/backfillWallColors";
import {
  ColorFetch,
  ALLOWED_IMAGE_HOSTS,
  dominantPaletteColors,
  fetchImageBuffer,
  PALETTE,
  wallColorsFor,
} from "../wallColors";

const SIZE = 48;

test.before(() => {
  mock.method(wallDepth, "wallDepthFor", async () => undefined);
});
test.after(() => mock.restoreAll());

function rgbOf(hex: string): [number, number, number] {
  return [parseInt(hex.slice(0, 2), 16), parseInt(hex.slice(2, 4), 16), parseInt(hex.slice(4, 6), 16)];
}

/** A 48 by 48 PNG made of vertical bands. Each band is a hex colour and a width in columns. */
function bandsPng(bands: Array<[string, number]>): Promise<Buffer> {
  const raw = Buffer.alloc(SIZE * SIZE * 3);
  let x = 0;
  for (const [hex, columns] of bands) {
    const [r, g, b] = rgbOf(hex);
    for (let c = 0; c < columns; c++, x++) {
      for (let y = 0; y < SIZE; y++) {
        const offset = (y * SIZE + x) * 3;
        raw[offset] = r;
        raw[offset + 1] = g;
        raw[offset + 2] = b;
      }
    }
  }
  assert.equal(x, SIZE);
  return sharp(raw, {raw: {width: SIZE, height: SIZE, channels: 3}}).png().toBuffer();
}

test("the palette has the twelve contract colours", () => {
  assert.deepEqual(PALETTE.map((c) => `${c.id}:${c.hex}`), [
    "red:cc0000", "orange:ff6600", "yellow:ffcc33", "green:669900", "teal:66cccc", "blue:0066cc",
    "purple:663399", "pink:ea4c88", "brown:663300", "black:000000", "grey:999999", "white:ffffff",
  ]);
});

test("a flat image of each palette colour maps to that colour", async () => {
  for (const {id, hex} of PALETTE) {
    assert.deepEqual(await dominantPaletteColors(await bandsPng([[hex, SIZE]])), [id], id);
  }
});

test("a mostly blue image with some white gives blue then white", async () => {
  const png = await bandsPng([["0066cc", 36], ["ffffff", 12]]);
  assert.deepEqual(await dominantPaletteColors(png), ["blue", "white"]);
});

test("a black and white split gives both, black first on a tie", async () => {
  const png = await bandsPng([["000000", 24], ["ffffff", 24]]);
  assert.deepEqual(await dominantPaletteColors(png), ["black", "white"]);
});

test("greys, near blacks and near whites do not turn into hues", async () => {
  assert.deepEqual(await dominantPaletteColors(await bandsPng([["808080", SIZE]])), ["grey"]);
  assert.deepEqual(await dominantPaletteColors(await bandsPng([["a6a6a6", SIZE]])), ["grey"]);
  assert.deepEqual(await dominantPaletteColors(await bandsPng([["111111", SIZE]])), ["black"]);
  assert.deepEqual(await dominantPaletteColors(await bandsPng([["f2f2f2", SIZE]])), ["white"]);
});

test("a shade of a hue maps to its palette colour", async () => {
  assert.deepEqual(await dominantPaletteColors(await bandsPng([["1a5fb4", SIZE]])), ["blue"]);
  assert.deepEqual(await dominantPaletteColors(await bandsPng([["b02020", SIZE]])), ["red"]);
});

test("a colour needs at least 12 percent of the image", async () => {
  const kept = await bandsPng([["0066cc", 42], ["cc0000", 6]]);
  assert.deepEqual(await dominantPaletteColors(kept), ["blue", "red"]);
  const dropped = await bandsPng([["0066cc", 43], ["cc0000", 5]]);
  assert.deepEqual(await dominantPaletteColors(dropped), ["blue"]);
});

test("at most three colours come back, most dominant first", async () => {
  const png = await bandsPng([["cc0000", 19], ["0066cc", 12], ["669900", 10], ["ffcc33", 7]]);
  assert.deepEqual(await dominantPaletteColors(png), ["red", "blue", "green"]);
});

test("the top colour is kept when no colour reaches 12 percent", async () => {
  const bands: Array<[string, number]> = PALETTE.slice(0, 10).map((c, i): [string, number] => [c.hex, i < 8 ? 5 : 4]);
  assert.deepEqual(await dominantPaletteColors(await bandsPng(bands)), ["red"]);
});

test("a transparent image counts as white", async () => {
  const png = await sharp({create: {width: 16, height: 16, channels: 4, background: {r: 0, g: 0, b: 0, alpha: 0}}})
    .png().toBuffer();
  assert.deepEqual(await dominantPaletteColors(png), ["white"]);
});

test("a grey scale image and a wide image decode", async () => {
  const grey = await sharp({create: {width: 64, height: 32, channels: 3, background: {r: 128, g: 128, b: 128}}})
    .greyscale().png().toBuffer();
  assert.deepEqual(await dominantPaletteColors(grey), ["grey"]);
  const wide = await sharp({create: {width: 400, height: 40, channels: 3, background: {r: 204, g: 0, b: 0}}})
    .jpeg().toBuffer();
  assert.deepEqual(await dominantPaletteColors(wide), ["red"]);
});

function replyOf(body: Uint8Array | string, init: {status?: number; headers?: Record<string, string>} = {}): Response {
  return new Response(typeof body === "string" ? body : Buffer.from(body), {status: init.status ?? 200, headers: init.headers});
}

test("fetchImageBuffer reads an https image and rejects bad replies", async () => {
  const ok: ColorFetch = async () => replyOf(new Uint8Array([1, 2, 3]));
  assert.deepEqual([...await fetchImageBuffer("https://raw.githubusercontent.com/o/r/main/a.png", ok)], [1, 2, 3]);
  await assert.rejects(fetchImageBuffer("http://raw.githubusercontent.com/o/r/main/a.png", ok), /https/);
  await assert.rejects(fetchImageBuffer("https://raw.githubusercontent.com/o/r/main/a.png", async () => replyOf("no", {status: 404})), /404/);
  const declared: ColorFetch = async () => replyOf(new Uint8Array(10), {headers: {"content-length": "999"}});
  await assert.rejects(fetchImageBuffer("https://raw.githubusercontent.com/o/r/main/a.png", declared, 100), /too large/);
  const streamed: ColorFetch = async () => replyOf(new Uint8Array(200));
  await assert.rejects(fetchImageBuffer("https://raw.githubusercontent.com/o/r/main/a.png", streamed, 100), /too large/);
});

const GOOD = "https://raw.githubusercontent.com/o/r/main/a.png";

function redirectTo(location: string, status = 302): Response {
  return new Response(null, {status, headers: {location}});
}

test("only the GitHub raw and prismwalls.com hosts are allowed", () => {
  assert.deepEqual([...ALLOWED_IMAGE_HOSTS], ["raw.githubusercontent.com", "prismwalls.com"]);
});

test("owned thumbnail endpoint is allowed without allowing other functions or original URLs", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  delete process.env.OWNED_THUMBNAIL_BASE_URL;
  process.env.GCLOUD_PROJECT = "prism-wallpapers";
  const base = "https://asia-south1-prism-wallpapers.cloudfunctions.net";
  const ok: ColorFetch = async () => replyOf(new Uint8Array([1, 2, 3]));
  assert.deepEqual([...await fetchImageBuffer(`${base}/ownedThumbnail/wall-1`, ok)], [1, 2, 3]);
  for (const url of [
    `${base}/original/wall-1`, `${base}/ownedThumbnail/wall-1?url=secret`,
    `${base}/ownedThumbnail/wall-1#secret`, `${base}/ownedThumbnail/a/b`,
    "https://evil.cloudfunctions.net/ownedThumbnail/wall-1",
  ]) await assert.rejects(fetchImageBuffer(url, ok), /not allowed/);
});

test("configured and staging thumbnail endpoints allow only an exact thumbnail path", async (t) => {
  const previous = {...process.env};
  t.after(() => {
    process.env = previous;
  });
  const ok: ColorFetch = async () => replyOf(new Uint8Array([1]));
  delete process.env.OWNED_THUMBNAIL_BASE_URL;
  process.env.GCLOUD_PROJECT = "prism-staging";
  assert.deepEqual([...await fetchImageBuffer(
    "https://asia-south1-prism-staging.cloudfunctions.net/ownedThumbnail/wall_1", ok)], [1]);
  process.env.OWNED_THUMBNAIL_BASE_URL = "https://images.example.com/private/preview/";
  assert.deepEqual([...await fetchImageBuffer("https://images.example.com/private/preview/wall-1", ok)], [1]);
  for (const url of [
    "https://images.example.com/private/preview/", "https://images.example.com/private/preview/a/b",
    "https://images.example.com/private/preview/wall?url=secret", "https://images.example.com/private/preview/wall#secret",
    "https://images.example.com/private/original/wall", "https://images.example.com/private/preview/%77all",
    "https://images.example.com.evil/private/preview/wall",
    "https://asia-south1-prism-staging.cloudfunctions.net/ownedThumbnail/wall",
  ]) await assert.rejects(fetchImageBuffer(url, ok), /not allowed/);
  for (const base of ["http://images.example.com/preview", "https://user:pass@images.example.com/preview",
    "https://images.example.com:8443/preview", "https://images.example.com/preview?x=1",
    "https://images.example.com/preview#fragment", "not-a-url"]) {
    process.env.OWNED_THUMBNAIL_BASE_URL = base;
    await assert.rejects(fetchImageBuffer("https://images.example.com/preview/wall", ok), /not allowed/);
  }
});

test("fetchImageBuffer refuses a bad url before any request", async () => {
  let calls = 0;
  const spy: ColorFetch = async () => {
    calls += 1;
    return replyOf(new Uint8Array([1]));
  };
  for (const url of [
    "https://evil.example/a.png",
    "https://raw.githubusercontent.com.evil.example/a.png",
    "https://evil.example/raw.githubusercontent.com/a.png",
    "https://169.254.169.254/latest/meta-data",
    "https://127.0.0.1/a.png",
    "https://[::1]/a.png",
    "https://user:pass@raw.githubusercontent.com/a.png",
    "https://raw.githubusercontent.com:8443/a.png",
    "http://raw.githubusercontent.com/a.png",
    "not a url",
  ]) {
    await assert.rejects(fetchImageBuffer(url, spy), {message: /^image/}, url);
  }
  assert.equal(calls, 0);
});

test("fetchImageBuffer sends every request with manual redirects", async () => {
  const seen: Array<string | undefined> = [];
  await fetchImageBuffer(GOOD, async (_url, init) => {
    seen.push(init.redirect);
    return replyOf(new Uint8Array([1]));
  });
  assert.deepEqual(seen, ["manual"]);
});

test("fetchImageBuffer follows a redirect inside the allowlist", async () => {
  const urls: string[] = [];
  const hop: ColorFetch = async (url) => {
    urls.push(url);
    if (urls.length === 1) return redirectTo("https://prismwalls.com/api/ai/assets/b.png", 301);
    if (urls.length === 2) return redirectTo("/api/ai/assets/c.png", 307);
    return replyOf(new Uint8Array([7]));
  };
  assert.deepEqual([...await fetchImageBuffer(GOOD, hop)], [7]);
  assert.deepEqual(urls, [GOOD, "https://prismwalls.com/api/ai/assets/b.png", "https://prismwalls.com/api/ai/assets/c.png"]);
});

test("fetchImageBuffer refuses a redirect to http, a foreign host, an internal address or nowhere", async () => {
  for (const location of [
    "http://raw.githubusercontent.com/a.png",
    "https://evil.example/a.png",
    "https://169.254.169.254/latest/meta-data",
    "http://localhost:8080/admin",
    "https://raw.githubusercontent.com:8443/a.png",
    "//evil.example/a.png",
  ]) {
    const urls: string[] = [];
    await assert.rejects(fetchImageBuffer(GOOD, async (url) => {
      urls.push(url);
      return redirectTo(location);
    }), {message: /^image/}, location);
    assert.deepEqual(urls, [GOOD], location);
  }
  await assert.rejects(fetchImageBuffer(GOOD, async () => new Response(null, {status: 302})), /no location/);
});

test("fetchImageBuffer allows three redirects and refuses a fourth", async () => {
  let calls = 0;
  const loop: ColorFetch = async () => {
    calls += 1;
    return redirectTo(GOOD);
  };
  await assert.rejects(fetchImageBuffer(GOOD, loop), /too many/);
  assert.equal(calls, 4);
  calls = 0;
  const three: ColorFetch = async () => {
    calls += 1;
    return calls <= 3 ? redirectTo(GOOD) : replyOf(new Uint8Array([1]));
  };
  assert.deepEqual([...await fetchImageBuffer(GOOD, three)], [1]);
});

test("wallColorsFor gives undefined for a wall image on a foreign host without a request", async () => {
  let calls = 0;
  const spy: ColorFetch = async () => {
    calls += 1;
    return replyOf(new Uint8Array([1]));
  };
  assert.equal(await wallColorsFor("w1", {wallpaper_thumb: "https://evil.example/t.png"}, spy), undefined);
  assert.equal(calls, 0);
});

test("fetchImageBuffer gives the request a timeout signal", async () => {
  let signal: AbortSignal | undefined;
  await fetchImageBuffer("https://raw.githubusercontent.com/o/r/main/a.png", async (_url, init) => {
    signal = init.signal;
    return replyOf(new Uint8Array([1]));
  });
  assert.ok(signal);
});

test("wallColorsFor reads the thumbnail first and never throws", async () => {
  const png = await bandsPng([["cc0000", SIZE]]);
  const urls: string[] = [];
  const ok: ColorFetch = async (url) => {
    urls.push(url);
    return replyOf(png);
  };
  const wall = {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/full.png", wallpaper_thumb: "https://raw.githubusercontent.com/o/r/main/thumb.png"};
  assert.deepEqual(await wallColorsFor("w1", wall, ok), ["red"]);
  assert.deepEqual(urls, ["https://raw.githubusercontent.com/o/r/main/thumb.png"]);
  assert.deepEqual(await wallColorsFor("w1", {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/full.png"}, ok), ["red"]);
  assert.equal(await wallColorsFor("w1", {}, ok), undefined);
  assert.equal(await wallColorsFor("w1", wall, async () => {
    throw new Error("offline");
  }), undefined);
  assert.equal(await wallColorsFor("w1", wall, async () => replyOf("not an image")), undefined);
});

test("wallColorsFor falls back to the full image when the thumbnail cannot be read", async () => {
  const png = await bandsPng([["cc0000", SIZE]]);
  const thumb = "https://raw.githubusercontent.com/o/r/main/thumb.png";
  const full = "https://raw.githubusercontent.com/o/r/main/full.png";
  const urls: string[] = [];
  const thumbFails: ColorFetch = async (url) => {
    urls.push(url);
    return url === thumb ? replyOf("gone", {status: 404}) : replyOf(png);
  };
  assert.deepEqual(await wallColorsFor("w1", {wallpaper_thumb: thumb, wallpaper_url: full}, thumbFails), ["red"]);
  assert.deepEqual(urls, [thumb, full]);
  urls.length = 0;
  const thumbUndecodable: ColorFetch = async (url) => {
    urls.push(url);
    return url === thumb ? replyOf("not an image") : replyOf(png);
  };
  assert.deepEqual(await wallColorsFor("w1", {wallpaper_thumb: thumb, wallpaper_url: full}, thumbUndecodable), ["red"]);
  assert.deepEqual(urls, [thumb, full]);
  urls.length = 0;
  assert.equal(await wallColorsFor("w1", {wallpaper_thumb: thumb, wallpaper_url: "https://evil.example/a.png"}, async (url) => {
    urls.push(url);
    return replyOf("gone", {status: 404});
  }), undefined);
  assert.deepEqual(urls, [thumb]);
});

function fakeWallsCollection(t: test.TestContext, updates: Array<Record<string, unknown>>, wall?: Record<string, unknown>) {
  t.mock.method(db, "collection", () => ({
    doc: () => ({
      get: async () => ({exists: true, data: () => wall}),
      update: async (data: Record<string, unknown>) => {
        updates.push(data);
      },
    }),
  }));
}

function fakeFetch(t: test.TestContext, reply: () => Promise<Response>): void {
  t.mock.method(globalThis, "fetch", reply);
}

const created = (data: Record<string, unknown>) => ({
  params: {wallId: "w1"},
  data: {data: () => data},
}) as unknown as Parameters<typeof onWallCategorize.run>[0];

test("a new wall gets its colours in the same update as its category", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWallsCollection(t, updates);
  const png = await bandsPng([["0066cc", 36], ["ffffff", 12]]);
  fakeFetch(t, async () => replyOf(png));
  t.mock.method(wallCategory, "detectLabels", async () => ["Mountain"]);
  await onWallCategorize.run(created({wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png"}));
  assert.equal(updates.length, 1);
  assert.equal(updates[0].category, "Nature");
  assert.deepEqual(updates[0].colors, ["blue", "white"]);
});

test("a colour failure does not stop categorization", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWallsCollection(t, updates);
  fakeFetch(t, async () => {
    throw new Error("offline");
  });
  t.mock.method(wallCategory, "detectLabels", async () => ["Mountain"]);
  await onWallCategorize.run(created({wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png"}));
  assert.equal(updates.length, 1);
  assert.equal(updates[0].category, "Nature");
  assert.equal("colors" in updates[0], false);
});

test("a label failure still saves the colours with the default category", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWallsCollection(t, updates);
  fakeFetch(t, async () => replyOf(await bandsPng([["cc0000", SIZE]])));
  t.mock.method(wallCategory, "detectLabels", async () => {
    throw new Error("vision down");
  });
  await onWallCategorize.run(created({wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png"}));
  assert.equal(updates[0].category, "General");
  assert.deepEqual(updates[0].colors, ["red"]);
});

test("a wall that already has a category still gets colours, once", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWallsCollection(t, updates);
  fakeFetch(t, async () => replyOf(await bandsPng([["cc0000", SIZE]])));
  t.mock.method(wallCategory, "detectLabels", async () => ["Space"]);
  await onWallCategorize.run(created({wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png", category: "Space"}));
  assert.deepEqual(updates, [{colors: ["red"], visionLabels: ["Space"]}]);
  updates.length = 0;
  await onWallCategorize.run(created({wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png", category: "Space", colors: ["blue"]}));
  assert.deepEqual(updates, [{visionLabels: ["Space"]}]);
});

test("a wall with an empty or invalid colours list gets its colours again", async (t) => {
  t.mock.method(wallCategory, "detectLabels", async () => ["Space"]);
  for (const colors of [[], ["nope"], ["blue", "nope"], "blue", [1]]) {
    const updates: Array<Record<string, unknown>> = [];
    fakeWallsCollection(t, updates);
    const fetchMock = t.mock.method(globalThis, "fetch", async () => replyOf(await bandsPng([["cc0000", SIZE]])));
    await onWallCategorize.run(created({
      wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png",
      category: "Space",
      colors,
    }));
    assert.equal(fetchMock.mock.callCount(), 1, JSON.stringify(colors));
    assert.deepEqual(updates, [{colors: ["red"], visionLabels: ["Space"]}], JSON.stringify(colors));
    fetchMock.mock.restore();
  }
});

test("a wall with a category and colours makes no request", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWallsCollection(t, updates);
  const fetchMock = t.mock.method(globalThis, "fetch", async () => replyOf(await bandsPng([["cc0000", SIZE]])));
  t.mock.method(wallCategory, "detectLabels", async () => ["Space"]);
  await onWallCategorize.run(created({
    wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png",
    category: "Space",
    colors: ["blue"],
  }));
  assert.equal(fetchMock.mock.callCount(), 0);
  assert.deepEqual(updates, [{visionLabels: ["Space"]}]);
});

test("the categorize callable writes colours with the category", async (t) => {
  const updates: Array<Record<string, unknown>> = [];
  fakeWallsCollection(t, updates, {email: "a@example.com", wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png"});
  fakeFetch(t, async () => replyOf(await bandsPng([["000000", 24], ["ffffff", 24]])));
  t.mock.method(wallCategory, "detectLabels", async () => ["Night"]);
  const result = await categorizeWallpaper.run({
    auth: {uid: "u1", token: {admin: true}},
    data: {wallId: "w1"},
  } as unknown as Parameters<typeof categorizeWallpaper.run>[0]);
  assert.equal(result.success, true);
  assert.equal(updates.length, 1);
  assert.deepEqual(updates[0].colors, ["black", "white"]);
});

type FakeWall = {id: string; data: Record<string, unknown>};

function fakeBackfillDb(
  walls: FakeWall[],
  updates: Array<[string, Record<string, unknown>]>,
  events?: string[],
) {
  const docOf = (wall: FakeWall) => ({
    id: wall.id,
    ref: {id: wall.id},
    get: (field: string) => wall.data[field],
    data: () => wall.data,
  });
  const collection = () => {
    let after: string | undefined;
    let max = 0;
    const query = {
      where: () => query,
      orderBy: () => query,
      limit: (n: number) => {
        max = n;
        return query;
      },
      startAfter: (id: string) => {
        after = id;
        return query;
      },
      get: async () => {
        const docs = walls.filter((w) => after === undefined || w.id > after).slice(0, max).map(docOf);
        return {docs, empty: docs.length === 0, size: docs.length};
      },
    };
    return query;
  };
  return {
    collection,
    bulkWriter: () => ({
      update: async (ref: {id: string}, data: Record<string, unknown>) => {
        updates.push([ref.id, data]);
      },
      flush: async () => {
        events?.push("flush");
      },
      close: async () => undefined,
    }),
  } as unknown as admin.firestore.Firestore;
}

test("the backfill is a dry run by default and skips walls that have colours", async () => {
  const png = await bandsPng([["cc0000", SIZE]]);
  const fetchImpl: ColorFetch = async () => replyOf(png);
  const walls: FakeWall[] = [
    {id: "a", data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png"}},
    {id: "b", data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/b.png", colors: ["blue"]}},
    {id: "c", data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/c.png"}},
    {id: "d", data: {}},
  ];
  const updates: Array<[string, Record<string, unknown>]> = [];
  const logs: string[] = [];
  const dry = await backfillWallColors(fakeBackfillDb(walls, updates), parseBackfillArgs([]), fetchImpl, (l) => logs.push(l));
  assert.deepEqual(dry, {scanned: 4, skipped: 1, colored: 2, failed: 1, written: 0});
  assert.deepEqual(updates, []);
  assert.ok(logs.some((l) => l.includes("last=")));

  const applied = await backfillWallColors(
    fakeBackfillDb(walls, updates), parseBackfillArgs(["--apply", "--batch=2"]), fetchImpl, () => undefined);
  assert.deepEqual(applied, {scanned: 4, skipped: 1, colored: 2, failed: 1, written: 2});
  assert.deepEqual(updates, [["a", {colors: ["red"]}], ["c", {colors: ["red"]}]]);
});

test("the backfill flushes its writes before it logs the batch cursor", async () => {
  const png = await bandsPng([["cc0000", SIZE]]);
  const fetchImpl: ColorFetch = async () => replyOf(png);
  const walls: FakeWall[] = ["a", "b", "c"].map((id) => ({
    id, data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/x.png"},
  }));
  const events: string[] = [];
  await backfillWallColors(
    fakeBackfillDb(walls, [], events), parseBackfillArgs(["--apply", "--batch=2"]), fetchImpl, (l) => events.push(l.split(" ")[0]));
  assert.deepEqual(events, ["flush", "batch", "flush", "batch", "done"]);
});

test("the backfill resumes after a document id and can force a rewrite", async () => {
  const png = await bandsPng([["cc0000", SIZE]]);
  const fetchImpl: ColorFetch = async () => replyOf(png);
  const walls: FakeWall[] = ["a", "b", "c"].map((id) => ({
    id, data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/x.png", colors: ["blue"]},
  }));
  const updates: Array<[string, Record<string, unknown>]> = [];
  const resumed = await backfillWallColors(
    fakeBackfillDb(walls, updates), parseBackfillArgs(["--apply", "--force", "--start-after=a"]), fetchImpl, () => undefined);
  assert.equal(resumed.scanned, 2);
  assert.deepEqual(updates.map(([id]) => id).sort(), ["b", "c"]);
});

test("backfill arguments fall back to safe values", () => {
  assert.deepEqual(parseBackfillArgs(["--batch=9999", "--start-after="]), {
    apply: false, force: false, batchSize: 100, startAfter: undefined,
  });
  assert.equal(parseBackfillArgs(["--apply"]).apply, true);
});

test("the backfill recomputes walls whose colours are not palette ids", async () => {
  const png = await bandsPng([["cc0000", SIZE]]);
  const fetchImpl: ColorFetch = async () => replyOf(png);
  const walls: FakeWall[] = [
    {id: "a", data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/a.png", colors: ["nope"]}},
    {id: "b", data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/b.png", colors: []}},
    {id: "c", data: {wallpaper_url: "https://raw.githubusercontent.com/o/r/main/c.png", colors: ["blue"]}},
  ];
  const updates: Array<[string, Record<string, unknown>]> = [];
  const counts = await backfillWallColors(fakeBackfillDb(walls, updates), parseBackfillArgs(["--apply"]), fetchImpl, () => undefined);
  assert.equal(counts.skipped, 1);
  assert.deepEqual(updates.map(([id]) => id).sort(), ["a", "b"]);
});
