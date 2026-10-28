import { test, expect } from "@playwright/test";

test("QR disclosure supports keyboard, touch, dismissal and reveal-only analytics", async ({ page }, testInfo) => {
  const events: string[] = [];
  await page.route("https://api-js.mixpanel.com/**", async (route) => {
    const body: unknown = route.request().postDataJSON();
    if (Array.isArray(body)) {
      for (const item of body) {
        if (typeof item === "object" && item !== null && "event" in item && typeof item.event === "string") {
          events.push(item.event);
        }
      }
    }
    await route.fulfill({ status: 200, body: "1" });
  });
  await page.goto("/");
  const button = page.getByRole("button", { name: "Scan QR Code" });
  await button.focus();
  await expect(button).toHaveAttribute("aria-expanded", "false");
  expect(events.filter((event) => event === "web_qr_viewed")).toHaveLength(0);
  await button.press("Enter");
  await expect(button).toHaveAttribute("aria-expanded", "true");
  const panel = page.getByRole("region", { name: "Scan to download Prism for Android" });
  await expect(panel).toBeVisible();
  await expect(panel).toHaveAttribute("id", (await button.getAttribute("aria-controls")) ?? "");
  await expect(panel.locator("svg")).toHaveCount(1);
  await button.press("Escape");
  await expect(panel).toBeHidden();
  await expect(button).toHaveAttribute("aria-expanded", "false");
  await button.press("Space");
  await expect(panel).toBeVisible();
  await page.getByRole("heading", { level: 1 }).click();
  await expect(panel).toBeHidden();
  await button.tap();
  await expect(panel).toBeVisible();
  await button.tap();
  await expect(panel).toBeHidden();
  await page.setViewportSize({ width: 390, height: 844 });
  await button.tap();
  await expect(panel).toBeVisible();
  await expect.poll(() => events.filter((event) => event === "web_qr_viewed").length).toBe(4);
  await page.screenshot({ path: testInfo.outputPath("qr-touch.png") });
});

test.describe("mouse interaction", () => {
  test.use({ hasTouch: false });

  test("hover opens the QR panel and keeps it open across the gap", async ({ page }, testInfo) => {
    await page.goto("/");
    const button = page.getByRole("button", { name: "Scan QR Code" });
    const panel = page.getByRole("region", { name: "Scan to download Prism for Android" });
    await expect(panel).toBeHidden();
    await button.hover();
    await expect(button).toHaveAttribute("aria-expanded", "true");
    await expect(panel).toBeVisible();
    const bounds = await button.boundingBox();
    if (!bounds) throw new Error("QR button has no bounds");
    await page.mouse.move(bounds.x + bounds.width / 2, bounds.y - 6, { steps: 10 });
    await expect(panel).toBeVisible();
    await panel.locator("svg").hover();
    await expect(panel).toBeVisible();
    await page.screenshot({ path: testInfo.outputPath("qr-hover.png") });
    await page.getByRole("heading", { level: 1 }).hover();
    await expect(panel).toBeHidden();
    await expect(button).toHaveAttribute("aria-expanded", "false");
  });

  test("click still toggles the QR panel after hovering", async ({ page }) => {
    await page.goto("/");
    const button = page.getByRole("button", { name: "Scan QR Code" });
    const panel = page.getByRole("region", { name: "Scan to download Prism for Android" });
    await button.hover();
    await expect(panel).toBeVisible();
    await button.click();
    await expect(panel).toBeHidden();
    await button.click();
    await expect(panel).toBeVisible();
    await button.press("Escape");
    await expect(panel).toBeHidden();
  });

  for (const edge of ["left", "right"] as const) {
    test(`hover stays open from the ${edge} button edge with enlarged text`, async ({ page }) => {
      await page.goto("/");
      await page.addStyleTag({ content: "html { font-size: 24px; }" });
      const button = page.getByRole("button", { name: "Scan QR Code" });
      const panel = page.getByRole("region", { name: "Scan to download Prism for Android" });
      await page.evaluate(() => document.fonts.ready);
      await button.hover();
      const bounds = await button.boundingBox();
      if (!bounds) throw new Error("QR button has no bounds");
      const x = edge === "left" ? 2 : bounds.width - 2;
      await button.hover({ position: { x, y: bounds.height / 2 } });
      await expect(panel).toBeVisible();
      await page.mouse.move(bounds.x + x, bounds.y - 6, { steps: 10 });
      await expect(panel).toBeVisible();
      await panel.locator("svg").hover();
      await expect(panel).toBeVisible();
    });
  }
});
