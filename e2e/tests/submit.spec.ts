import { test, expect } from "@playwright/test";
import { submit } from "./helpers";

const DRIVE_URL = "https://drive.google.com/file/d/e2e-submit/view";

test("submitting a URL creates a summary page", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Summarize a video" })).toBeVisible();

  const id = await submit(page, DRIVE_URL);
  expect(id).toBeGreaterThan(0);
  await expect(page.locator("[data-status]")).toHaveText(/^(pending|downloading|transcribing|summarizing|done)$/);
  await expect(page.getByRole("link", { name: DRIVE_URL })).toBeVisible();
});

test("invalid URL stays on the form with an error", async ({ page }) => {
  await page.goto("/");
  // Bypass the browser's native type=url validation to reach the server-side check.
  await page.locator("input[name='summary[source_url]']").evaluate((el) => el.removeAttribute("type"));
  await page.locator("input[name='summary[source_url]']").fill("not a url");
  await page.getByRole("button", { name: "Summarize" }).click();

  await expect(page).not.toHaveURL(/\/summaries\/\d+/);
  await expect(page.locator(".error")).toContainText("must be an http(s) URL");
  await expect(page.getByRole("button", { name: "Summarize" })).toBeVisible();
});
