import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./test/e2e",
  workers: 1,
  use: {
    baseURL: "http://127.0.0.1:3107",
    browserName: "chromium",
    hasTouch: true,
    trace: "retain-on-failure",
  },
  webServer: {
    command: "npm run dev -- --hostname 127.0.0.1 --port 3107",
    url: "http://127.0.0.1:3107",
    env: { NEXT_PUBLIC_MIXPANEL_TOKEN: "public-test-token" },
    reuseExistingServer: false,
    timeout: 120_000,
  },
});
