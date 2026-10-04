import { test, expect } from "@playwright/test";
import { submit, STATUSES } from "./helpers";

declare global {
  interface Window {
    __statuses: string[];
  }
}

test("status advances through every step without a page reload", async ({ page }) => {
  const sockets: string[] = [];
  page.on("websocket", (ws) => sockets.push(ws.url()));
  let navigations = 0;
  page.on("framenavigated", (frame) => {
    if (frame === page.mainFrame()) navigations++;
  });

  await submit(page, "https://drive.google.com/file/d/e2e-live/view");
  const navigationsAfterSubmit = navigations;

  // Record every value the badge takes, from inside the page, so no transition is missed.
  await page.evaluate(() => {
    window.__statuses = [document.querySelector("[data-status]")!.getAttribute("data-status")!];
    new MutationObserver(() => {
      const status = document.querySelector("[data-status]")!.getAttribute("data-status")!;
      if (window.__statuses.at(-1) !== status) window.__statuses.push(status);
    }).observe(document.body, { subtree: true, childList: true, attributes: true });
  });

  await expect(page.locator("[data-status]")).toHaveText("done", { timeout: 20_000 });

  const seen = await page.evaluate(() => window.__statuses);
  // Every step from the first one observed up to "done", in order, nothing skipped.
  expect(seen).toEqual(STATUSES.slice(STATUSES.indexOf(seen[0] as (typeof STATUSES)[number])));
  expect(seen.length).toBeGreaterThanOrEqual(3);

  expect(navigations).toBe(navigationsAfterSubmit);
  expect(sockets.some((url) => url.includes("/cable"))).toBe(true);
});
