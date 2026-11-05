import { test, expect, type Locator, type Page } from "@playwright/test";

const ORIGIN = "http://127.0.0.1:3108";

test.use({ viewport: { width: 1440, height: 900 }, hasTouch: false });

async function shareCodes(page: Page): Promise<Record<string, string>> {
  const response = await page.request.get(`${ORIGIN}/__codes`);
  expect(response.ok(), "the fixture server returns the share codes").toBe(true);
  return response.json();
}

async function serveWallThumbs(page: Page) {
  await page.route("https://img.prismwalls.com/**", async (route) => {
    await route.fulfill({ response: await page.request.get(`${ORIGIN}/__preview.jpg`) });
  });
}

async function boxOf(locator: Locator, label: string) {
  await expect(locator, `${label} is visible`).toBeVisible();
  const bounds = await locator.boundingBox();
  if (!bounds) throw new Error(`${label} has no bounds`);
  return bounds;
}

async function hasNoHorizontalScroll(page: Page): Promise<boolean> {
  return page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth);
}

test("short link with the desktop hint opens desktop mode, desktop version first", async ({ page }) => {
  await serveWallThumbs(page);
  const { DW1 } = await shareCodes(page);
  await page.goto(`${ORIGIN}/l/${DW1}?d=1`);
  await expect(page, "the short link redirects to the desktop wall page").toHaveURL(/\/wallpaper\/DW1\?view=desktop$/);
  await expect(page.locator("main.desktop-mode"), "desktop mode is on").toBeVisible();

  const desktop = await boxOf(page.locator(".desktop-stage .desktop-lead img"), "desktop image");
  const phone = await boxOf(page.locator(".desktop-stage .phone-side img"), "phone image");
  expect(desktop.width, "the desktop image is at least 2.5 times wider than the phone image")
    .toBeGreaterThanOrEqual(phone.width * 2.5);
  expect(phone.x, "the phone image sits to the right of the desktop image").toBeGreaterThanOrEqual(desktop.x + desktop.width);
  expect(
    Math.max(desktop.y, phone.y) < Math.min(desktop.y + desktop.height, phone.y + phone.height),
    "the desktop and phone images overlap vertically",
  ).toBe(true);

  const desktopFirst = await page.locator(".desktop-lead").evaluate((lead) => {
    const phoneFigure = document.querySelector(".phone-side");
    return phoneFigure !== null && (lead.compareDocumentPosition(phoneFigure) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0;
  });
  expect(desktopFirst, "the desktop figure comes before the phone figure in the DOM").toBe(true);

  await expect(
    page.getByRole("link", { name: /Download 1920 × 1200/ }),
    "the desktop download link is named and points at the desktop file",
  ).toHaveAttribute("href", /\/api\/catalog\/download\/DW1\/desktop\.jpg$/);
  await expect(page.getByText("The full 2560 × 1600 desktop file is in Prism."), "the full-size note is shown").toBeVisible();
  await expect(page.locator("[role=tablist]"), "desktop mode has no phone and desktop tabs").toHaveCount(0);
  expect(await hasNoHorizontalScroll(page), "the page does not scroll horizontally").toBe(true);

  await page.screenshot({ path: "test-results/desktop-mode-with-companion.png", fullPage: true });
});

test("wall without a desktop version shows the phone wall and the how-to note", async ({ page }) => {
  await serveWallThumbs(page);
  const { W1 } = await shareCodes(page);
  await page.goto(`${ORIGIN}/l/${W1}?d=1`);
  await expect(page, "the short link redirects to the desktop wall page").toHaveURL(/\/wallpaper\/W1\?view=desktop$/);
  await expect(page.locator("main img.wall-img"), "the phone image is visible").toBeVisible();
  await expect(page.getByRole("heading", { name: "Use it on your computer" }), "the how-to heading is shown").toBeVisible();
  await expect(page.getByText("Set as desktop background"), "the Windows step is shown").toBeVisible();
  await expect(page.getByText("Set Desktop Picture"), "the Mac step is shown").toBeVisible();
  await expect(page.locator(".desktop-lead"), "there is no desktop figure").toHaveCount(0);
  await expect(page.locator('img[src*="/api/catalog/desktop/"]'), "no desktop image is requested").toHaveCount(0);

  await page.screenshot({ path: "test-results/desktop-mode-no-companion.png", fullPage: true });
});

test("gated wall never shows its image in desktop mode", async ({ page }) => {
  await page.goto(`${ORIGIN}/wallpaper/G1?view=desktop`);
  await expect(page.getByText("Get it in Prism").first(), "the gated call to action is shown").toBeVisible();
  await expect(
    page.locator('img[src*="/api/catalog/preview/"], img[src*="/api/catalog/desktop/"]'),
    "no preview or desktop image is rendered",
  ).toHaveCount(0);
  await expect(page.locator('a[href*="/api/catalog/download/"]'), "no download link is rendered").toHaveCount(0);
});

test("narrow width stacks the desktop image above the phone image", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await serveWallThumbs(page);
  await page.goto(`${ORIGIN}/wallpaper/DW1?view=desktop`);

  const desktop = await boxOf(page.locator(".desktop-stage .desktop-lead img"), "desktop image");
  const phone = await boxOf(page.locator(".desktop-stage .phone-side img"), "phone image");
  expect(phone.y, "the phone image starts below the desktop image").toBeGreaterThanOrEqual(desktop.y + desktop.height);
  expect(await hasNoHorizontalScroll(page), "the page does not scroll horizontally at phone width").toBe(true);
});
