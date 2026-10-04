import { expect, type Page } from "@playwright/test";

export const STATUSES = ["pending", "downloading", "transcribing", "summarizing", "done"] as const;

/** Submits the form and lands on /summaries/:id. Refuses to run against a stack that would call real APIs. */
export async function submit(page: Page, url: string): Promise<number> {
  await page.goto("/");
  expect(await page.locator("body").getAttribute("data-fake-services"), "stack must run with FAKE_SERVICES=true").toBe("true");
  await page.getByPlaceholder(/drive.google.com/).fill(url);
  await page.getByRole("button", { name: "Summarize" }).click();
  await expect(page).toHaveURL(/\/summaries\/\d+$/);
  return Number(page.url().match(/\/summaries\/(\d+)$/)![1]);
}

/** Waits (without reloading) until the status badge shows a terminal state. */
export async function waitForFinished(page: Page, timeout = 20_000) {
  await expect(page.locator("[data-status]")).toHaveText(/^(done|failed)$/, { timeout });
  return (await page.locator("[data-status]").textContent())!.trim();
}
