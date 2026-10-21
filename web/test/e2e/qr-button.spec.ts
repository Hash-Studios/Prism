import { test, expect } from "@playwright/test";

test("QR disclosure supports keyboard, pointer, touch, dismissal and reveal-only analytics", async ({ page }) => {
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
  await button.hover();
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
  await button.click();
  await expect(panel).toBeVisible();
  await button.click();
  await expect(panel).toBeHidden();
  await button.tap();
  await expect(panel).toBeVisible();
  await expect.poll(() => events.filter((event) => event === "web_qr_viewed").length).toBe(4);
});
