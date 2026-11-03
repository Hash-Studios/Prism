import { test, expect, type Page } from "@playwright/test";

const RELEASES_URL = "https://api.github.com/repos/Hash-Studios/Prism/releases?per_page=10";
const CACHE_KEY = "prism.apkRelease.v1";
const APK_URL = "https://github.com/Hash-Studios/Prism/releases/download/v3.18.2%2B359/prism-3.18.2-359.apk";
const RELEASES_PAGE_URL = "https://github.com/Hash-Studios/Prism/releases";
const LATEST_URL = "https://github.com/Hash-Studios/Prism/releases/latest";
const PLAY_URL = "https://play.google.com/store/apps/details?id=com.hash.prism";

function releases(apkVersion = "3.18.2", code = 359) {
  const tag = `v${apkVersion}+${code}`;
  const tagEncoded = `v${apkVersion}%2B${code}`;
  const apkName = `prism-${apkVersion}-${code}.apk`;
  const downloadBase = `https://github.com/Hash-Studios/Prism/releases/download/${tagEncoded}`;
  return [
    {
      tag_name: "v3.18.3+360",
      draft: false,
      prerelease: false,
      html_url: "https://github.com/Hash-Studios/Prism/releases/tag/v3.18.3%2B360",
      assets: [
        {
          name: "app-release-360.aab",
          size: 1,
          browser_download_url: "https://github.com/x/app-release-360.aab",
          digest: "sha256:" + "1".repeat(64),
        },
      ],
    },
    {
      tag_name: tag,
      draft: false,
      prerelease: false,
      html_url: `https://github.com/Hash-Studios/Prism/releases/tag/${tagEncoded}`,
      assets: [
        {
          name: apkName,
          size: 54632448,
          browser_download_url: `${downloadBase}/${apkName}`,
          digest: "sha256:" + "ab".repeat(32),
        },
        {
          name: `${apkName}.sha256`,
          size: 87,
          browser_download_url: `${downloadBase}/${apkName}.sha256`,
          digest: "sha256:" + "2".repeat(64),
        },
      ],
    },
  ];
}

type GitHubMock = { calls: number; status: number };

async function mockGitHub(page: Page, github: GitHubMock) {
  await page.route(RELEASES_URL, async (route) => {
    github.calls += 1;
    if (github.status !== 200) {
      await route.fulfill({ status: github.status, contentType: "application/json", body: "{}" });
      return;
    }
    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify(releases()) });
  });
}

test.beforeEach(async ({ page }) => {
  await page.route("https://api-js.mixpanel.com/**", (route) => route.fulfill({ status: 200, body: "1" }));
});

test("shows the latest release with an APK, Play first", async ({ page }) => {
  const github: GitHubMock = { calls: 0, status: 200 };
  await mockGitHub(page, github);
  await page.goto("/download");
  const details = page.getByTestId("apk-details");
  await expect(details).toContainText("3.18.2 (359)");
  await expect(details).toContainText("52.1 MB");
  await expect(details.locator("code")).toHaveText("ab".repeat(32));

  const apkLink = page.getByRole("link", { name: /^Download APK/ });
  await expect(apkLink).toHaveAttribute("href", APK_URL);

  const playLink = page.getByRole("link", { name: "Get it on Google Play" });
  await expect(playLink).toHaveAttribute("href", PLAY_URL);

  const hrefs = await page.locator("a").evaluateAll((els) => els.map((el) => el.getAttribute("href")));
  const playIndex = hrefs.indexOf(PLAY_URL);
  const apkIndex = hrefs.indexOf(APK_URL);
  expect(playIndex).toBeGreaterThanOrEqual(0);
  expect(apkIndex).toBeGreaterThanOrEqual(0);
  expect(playIndex).toBeLessThan(apkIndex);

  expect(github.calls).toBe(1);
});

test("GitHub API failure shows a fallback link", async ({ page }) => {
  const github: GitHubMock = { calls: 0, status: 403 };
  await mockGitHub(page, github);
  await page.goto("/download");
  const status = page.getByTestId("apk-status");
  await expect(status).toContainText("Unable to load the latest release");
  await expect(page.getByRole("link", { name: "See all releases on GitHub" })).toHaveAttribute(
    "href",
    RELEASES_PAGE_URL,
  );
  await expect(page.getByRole("link", { name: /^Download APK/ })).toHaveAttribute("href", LATEST_URL);
});

test("a fresh cache skips the API", async ({ page }) => {
  const github: GitHubMock = { calls: 0, status: 200 };
  await mockGitHub(page, github);
  await page.goto("/download");
  await expect(page.getByTestId("apk-details")).toContainText("3.18.2 (359)");
  expect(github.calls).toBe(1);

  await page.reload();
  await expect(page.getByTestId("apk-details")).toContainText("3.18.2 (359)");
  expect(github.calls).toBe(1);
});

test("a stale cache refreshes, and survives an API failure", async ({ page }) => {
  const github: GitHubMock = { calls: 0, status: 200 };
  await mockGitHub(page, github);
  await page.goto("/download");
  await expect(page.getByTestId("apk-details")).toContainText("3.18.2 (359)");
  expect(github.calls).toBe(1);

  await page.evaluate((key) => {
    const v = JSON.parse(localStorage.getItem(key)!);
    v.fetchedAt = Date.now() - 2 * 60 * 60 * 1000;
    localStorage.setItem(key, JSON.stringify(v));
  }, CACHE_KEY);

  github.status = 500;
  await page.reload();
  await expect.poll(() => github.calls).toBe(2);
  await expect(page.getByTestId("apk-details")).toContainText("3.18.2 (359)");
});

test("no horizontal scroll at phone width with large text", async ({ page }) => {
  const github: GitHubMock = { calls: 0, status: 200 };
  await mockGitHub(page, github);
  await page.setViewportSize({ width: 360, height: 800 });
  await page.goto("/download");
  await page.addStyleTag({ content: "html { font-size: 24px; }" });
  await expect(page.getByTestId("apk-details")).toContainText("3.18.2 (359)");
  expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(360);
});
