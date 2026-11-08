import { test, expect, type Page } from "@playwright/test";
import { amoledWalls, previewPath } from "../../lib/amoled-walls";
import { topicPages } from "../../lib/seo-pages";

const PLAY_URL = "https://play.google.com/store/apps/details?id=com.hash.prism";
const GITHUB_URL = "https://github.com/Hash-Studios/Prism";
const SITE = "https://prismwalls.com";
const AMOLED = "/amoled-wallpapers";
const OPEN_SOURCE = "/open-source-android-wallpaper-app";
const APK_URL = "https://github.com/Hash-Studios/Prism/releases/download/v3.24.0%2B366/prism-3.24.0-366.apk";
// A 9 × 20 black JPEG, the shape of the real previews.
const JPEG = Buffer.from(
  "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDABALDA4MChAODQ4SERATGCgaGBYWGDEjJR0oOjM9PDkzODdASFxOQERXRTc4UG1RV19iZ2hnPk1xeXBkeFxlZ2P/wAALCAAUAAkBAREA/8QAFQABAQAAAAAAAAAAAAAAAAAAAAf/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oACAEBAAA/AJ+AD//Z",
  "base64",
);

type Sent = { event: string; properties: Record<string, unknown>; body: string };

async function scrollThrough(page: Page) {
  for (let y = 0; y < (await page.evaluate(() => document.body.scrollHeight)); y += 400) {
    await page.evaluate((top) => window.scrollTo(0, top), y);
    await page.waitForTimeout(50);
  }
}

async function stubNetwork(page: Page): Promise<{ sent: Sent[]; previews: string[] }> {
  const sent: Sent[] = [];
  const previews: string[] = [];
  const context = page.context();
  await context.route("https://api-js.mixpanel.com/**", async (route) => {
    const body = route.request().postData() ?? "";
    const parsed: unknown = JSON.parse(body);
    if (Array.isArray(parsed)) {
      for (const item of parsed) sent.push({ event: item.event, properties: item.properties, body });
    }
    await route.fulfill({ status: 200, body: "1" });
  });
  await context.route("**/api/catalog/preview/*.jpg", async (route) => {
    previews.push(new URL(route.request().url()).pathname);
    await route.fulfill({ status: 200, contentType: "image/jpeg", body: JPEG });
  });
  await context.route(/^https:\/\/(play\.google\.com|apps\.apple\.com|github\.com)\//, (route) =>
    route.fulfill({ status: 200, contentType: "text/html", body: "<title>outside</title>" }));
  return { sent, previews };
}

test.describe("without JavaScript", () => {
  test.use({ javaScriptEnabled: false });

  for (const slug of ["amoled-wallpapers", "open-source-android-wallpaper-app"] as const) {
    test(`${slug} has its own metadata in the HTML`, async ({ page }) => {
      await stubNetwork(page);
      await page.goto(`/${slug}`);
      const { title, description } = topicPages[slug];
      await expect(page).toHaveTitle(title);
      await expect(page.locator('meta[name="description"]')).toHaveAttribute("content", description);
      await expect(page.locator('link[rel="canonical"]')).toHaveAttribute("href", `${SITE}/${slug}`);
      await expect(page.locator('meta[property="og:url"]')).toHaveAttribute("content", `${SITE}/${slug}`);
      await expect(page.locator("h1")).toHaveCount(1);
      expect(description.length).toBeLessThanOrEqual(160);
      const text = await page.locator("main").innerText();
      // No store rating, install count, price or promotional figure.
      expect(text).not.toMatch(/\d+(\.\d+)?\s?[KM]\+|[$₹€£]\s?\d|\brating|\d(\.\d)?\s?stars|\binstalls\b/i);
    });
  }

  test("titles and descriptions differ between the topic pages", async () => {
    const pages = Object.values(topicPages);
    expect(new Set(pages.map((page) => page.title)).size).toBe(pages.length);
    expect(new Set(pages.map((page) => page.description)).size).toBe(pages.length);
  });

  test("AMOLED page renders every audited wall as static HTML", async ({ page }) => {
    const { previews } = await stubNetwork(page);
    await page.goto(AMOLED);
    await expect(page.locator("h1")).toHaveText("AMOLED wallpapers with black backgrounds");
    const images = page.locator("main ul img");
    await expect(images).toHaveCount(amoledWalls.length);
    expect(new Set(amoledWalls.map((wall) => wall.id)).size).toBe(amoledWalls.length);
    for (const [index, wall] of amoledWalls.entries()) {
      const image = images.nth(index);
      await expect(image).toHaveAttribute("src", previewPath(wall.id));
      await expect(image).toHaveAttribute("width", "1152");
      await expect(image).toHaveAttribute("height", "2560");
      await expect(image).toHaveAttribute("alt", `${wall.title}, AMOLED wallpaper by Prism Studio`);
      if (index === 0) await expect(image).not.toHaveAttribute("loading", /.*/);
      else await expect(image).toHaveAttribute("loading", "lazy");
      const card = page.locator("main li").filter({ has: page.locator(`img[src="${previewPath(wall.id)}"]`) });
      await expect(card.getByRole("link", { name: wall.title })).toHaveAttribute("href", `/wallpaper/${wall.id}`);
      await expect(card.getByRole("link", { name: "Prism Studio" })).toHaveAttribute("href", "/creator/PrismStudio");
      await expect(card).toContainText(wall.description);
      await expect(card).toContainText("1440 × 3200");
    }
    await expect(page.getByAltText("Prism's Themes screen, with AMOLED listed under Dark Themes")).toHaveAttribute(
      "loading", "lazy");
    await expect(page.getByText("Captured on iPhone.")).toBeVisible();
    const sources = await page.locator("img").evaluateAll((els) => els.map((el) => el.getAttribute("src") ?? ""));
    expect(sources.filter((src) => src.includes("img.prismwalls.com"))).toEqual([]);
    expect(previews.every((path) => /^\/api\/catalog\/preview\/[A-Z0-9]{10}\.jpg$/.test(path))).toBe(true);
    await expect(page.getByRole("link", { name: "Get it on Google Play" })).toHaveAttribute("href", PLAY_URL);
    await expect(page.getByRole("link", { name: "Other ways to install" })).toHaveAttribute("href", "/download");
  });

  test("open-source page links the store, the source and the APK page", async ({ page }) => {
    await stubNetwork(page);
    await page.goto(OPEN_SOURCE);
    await expect(page.locator("h1")).toHaveText("An open-source wallpaper app for Android");
    const main = page.locator("main");
    await expect(main.getByRole("link", { name: "Get it on Google Play" })).toHaveAttribute("href", PLAY_URL);
    await expect(main.getByRole("link", { name: "Source on GitHub" })).toHaveAttribute("href", GITHUB_URL);
    await expect(main.getByRole("link", { name: "Download the APK" })).toHaveAttribute("href", "/download");
    await expect(main.getByRole("link", { name: "BSD 3-Clause" })).toHaveAttribute(
      "href", `${GITHUB_URL}/blob/master/LICENSE.txt`);
    await expect(main).toContainText("It does not cover the wallpapers in the app.");
    await expect(main).toContainText("Prism Pro is a subscription.");
    const android = main.getByAltText("Prism's set-wallpaper sheet with Home screen, Lock screen and Both");
    await expect(android).toHaveAttribute("src", "/assets/screenshots/android-set-wallpaper-sheet.webp");
    await expect(main).toContainText("Android app capture, October 2026.");
    await expect(main).toContainText("downloads use Prism Coins, which you can earn in the app");
    await expect(main).toContainText("The Themes screen, captured on iPhone.");
    await expect(main.getByRole("link", { name: "AMOLED wallpapers", exact: true })).toHaveAttribute("href", AMOLED);
  });
});

test("both sitemaps list the new pages", async ({ request }) => {
  for (const path of ["/sitemap.xml", "/sitemap-pages.xml"]) {
    const body = await (await request.get(path)).text();
    expect(body).toContain(`<loc>${SITE}${AMOLED}</loc>`);
    expect(body).toContain(`<loc>${SITE}${OPEN_SOURCE}</loc>`);
  }
});

test("the existing crawler homepage and resource index link to both pages", async ({ request }) => {
  for (const path of ["/index.md", "/llms.txt"]) {
    const response = await request.get(path);
    expect(response.ok()).toBe(true);
    const body = await response.text();
    expect(body).toContain(`](${AMOLED})`);
    expect(body).toContain(`](${OPEN_SOURCE})`);
  }
});

test("the homepage and the other topic pages link to both pages", async ({ page }) => {
  await stubNetwork(page);
  for (const path of ["/", "/4k-wallpapers", "/collections", AMOLED, OPEN_SOURCE]) {
    await page.goto(path);
    const hrefs = await page.locator("main a").evaluateAll((els) => els.map((el) => el.getAttribute("href")));
    for (const target of [AMOLED, OPEN_SOURCE].filter((target) => target !== path)) {
      expect(hrefs, `${path} links to ${target}`).toContain(target);
    }
  }
});

for (const width of [360, 1280]) {
  test(`no sideways scroll at ${width} px`, async ({ page }) => {
    await stubNetwork(page);
    await page.setViewportSize({ width, height: 800 });
    for (const path of [AMOLED, OPEN_SOURCE]) {
      await page.goto(path);
      await scrollThrough(page);
      await page.waitForLoadState("networkidle");
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      expect(overflow, path).toBeLessThanOrEqual(0);
    }
  });
}

test("AMOLED page loads every preview once the page is scrolled", async ({ page }) => {
  const { previews } = await stubNetwork(page);
  await page.setViewportSize({ width: 360, height: 800 });
  await page.goto(AMOLED);
  await scrollThrough(page);
  await expect.poll(() => new Set(previews).size).toBe(amoledWalls.length);
  const sizes = await page.locator("main ul img").evaluateAll((els) =>
    els.map((el) => (el instanceof HTMLImageElement ? [el.naturalWidth, el.clientWidth] : [0, 0])));
  for (const [natural, shown] of sizes) {
    expect(natural).toBeGreaterThan(0);
    expect(shown).toBeLessThan(1152);
  }
});

test("store, download and APK clicks keep the entry page and send no private data", async ({ page }) => {
  const { sent } = await stubNetwork(page);
  await page.route("https://api.github.com/repos/Hash-Studios/Prism/releases?per_page=10", (route) =>
    route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify([{
      draft: false, prerelease: false, html_url: `${GITHUB_URL}/releases/tag/v3.24.0%2B366`,
      assets: [{ name: "prism-3.24.0-366.apk", size: 54632448, browser_download_url: APK_URL }],
    }]) }));

  await page.goto(`${OPEN_SOURCE}?utm_source=search_test&email=jane@example.com`);
  await expect.poll(() => sent.map((item) => item.event)).toContain("web_landing_viewed");
  const popup = page.waitForEvent("popup");
  await page.locator("main").getByRole("link", { name: "Get it on Google Play" }).click();
  await (await popup).close();
  await page.locator("main").getByRole("link", { name: "Download the APK" }).click();
  await page.waitForURL("**/download");
  await expect(page.getByRole("link", { name: /^Download APK/ })).toHaveAttribute("href", APK_URL);
  await page.getByRole("link", { name: /^Download APK/ }).click();
  await expect.poll(() => sent.some((item) => item.event === "web_apk_clicked")).toBe(true);

  // next dev runs effects twice, so each page view can be sent twice. Clicks are sent once.
  const named = (event: string) => sent.filter((item) => item.event === event).map((item) => item.properties);
  expect(named("web_store_clicked")).toHaveLength(1);
  expect(named("web_download_clicked")).toHaveLength(1);
  expect(named("web_apk_clicked")).toHaveLength(1);
  const landing = named("web_landing_viewed")[0];
  const downloadPage = named("web_landing_viewed").at(-1);
  const [store] = named("web_store_clicked");
  const [download] = named("web_download_clicked");
  const [apk] = named("web_apk_clicked");
  expect(landing).toMatchObject({ path: OPEN_SOURCE, entry_path: OPEN_SOURCE, utm_source: "search_test" });
  expect(store).toMatchObject({ path: OPEN_SOURCE, store: "google_play" });
  expect(download).toMatchObject({ path: OPEN_SOURCE, entry_path: OPEN_SOURCE });
  expect(downloadPage).toMatchObject({ path: "/download", entry_path: OPEN_SOURCE, utm_source: "search_test" });
  expect(apk).toMatchObject({
    path: "/download", entry_path: OPEN_SOURCE, utm_source: "search_test", target: "apk_file", apk_version: "3.24.0",
  });
  for (const item of sent) {
    expect(item.body).not.toMatch(/jane|example\.com|email|github\.com|\.apk|referrer|current_url/);
  }
});

test("Global Privacy Control stops all website events", async ({ page }) => {
  const { sent } = await stubNetwork(page);
  await page.addInitScript(() => Object.defineProperty(Navigator.prototype, "globalPrivacyControl", { get: () => true }));
  await page.goto(AMOLED);
  await expect(page.locator("h1")).toBeVisible();
  const popup = page.waitForEvent("popup");
  await page.locator("main").getByRole("link", { name: "Get it on Google Play" }).click();
  await (await popup).close();
  await page.waitForTimeout(500);
  expect(sent).toEqual([]);
});

test("the privacy page discloses website analytics", async ({ page }) => {
  await stubNetwork(page);
  await page.goto("/privacy");
  const section = page.locator("section").filter({ has: page.getByRole("heading", { name: "This Website" }) });
  await expect(section).toContainText("Website analytics does not use cookies.");
  await expect(section).toContainText("Do Not Track or Global Privacy Control");
  await expect(section).toContainText("An APK click also carries the app version.");
});
