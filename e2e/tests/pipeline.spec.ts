import { test, expect } from "@playwright/test";
import { submit, waitForFinished } from "./helpers";

test("a submitted link ends in done with summary and transcript", async ({ page }) => {
  await submit(page, "https://drive.google.com/file/d/e2e-ok/view");
  expect(await waitForFinished(page)).toBe("done");

  await expect(page.getByRole("heading", { name: "Summary", exact: true })).toBeVisible();
  await expect(page.locator(".markdown")).toContainText("TL;DR");
  await expect(page.getByRole("heading", { name: "Transcript" })).toBeVisible();
  const rows = page.locator(".transcript tr");
  await expect(rows).toHaveCount(4);
  await expect(rows.first().locator(".ts")).toHaveText("00:00");
  await expect(rows.nth(2).locator(".ts")).toHaveText("00:07");
});

test("a link the downloader rejects ends in failed with the reason", async ({ page }) => {
  await submit(page, "https://drive.google.com/file/d/e2e-fail/view");
  expect(await waitForFinished(page)).toBe("failed");
  await expect(page.locator(".error")).toContainText("Unable to download");
  await expect(page.getByRole("heading", { name: "Transcript" })).toHaveCount(0);
});
