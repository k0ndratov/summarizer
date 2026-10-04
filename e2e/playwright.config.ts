import { defineConfig, devices } from "@playwright/test";

// Runs against the docker compose stack. Start it with `make start` (or let
// webServer below bring it up). The stack must run with FAKE_SERVICES=true so
// no external APIs are called.
export default defineConfig({
  testDir: "./tests",
  timeout: 30_000,
  fullyParallel: false,
  retries: 0,
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: process.env.BASE_URL ?? "http://localhost:3000",
    trace: "retain-on-failure",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: "cd .. && docker compose up -d --wait",
    url: "http://localhost:3000/up",
    reuseExistingServer: true,
    timeout: 180_000,
  },
});
