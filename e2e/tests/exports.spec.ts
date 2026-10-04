import { test, expect } from "@playwright/test";
import { readFile } from "node:fs/promises";
import { submit, waitForFinished } from "./helpers";

test("all four exports download with the expected content", async ({ page }) => {
  const id = await submit(page, "https://drive.google.com/file/d/e2e-exports/view");
  expect(await waitForFinished(page)).toBe("done");

  const files: Record<string, string> = {};
  for (const fmt of ["srt", "txt", "md", "json"]) {
    const downloadPromise = page.waitForEvent("download");
    await page.locator(".downloads").getByRole("link", { name: fmt, exact: true }).click();
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe(`summary-${id}.${fmt}`);
    files[fmt] = await readFile((await download.path())!, "utf8");
  }

  const srtLines = files.srt.split("\n");
  expect(srtLines[0]).toBe("1");
  expect(srtLines[1]).toMatch(/^\d\d:\d\d:\d\d,\d{3} --> \d\d:\d\d:\d\d,\d{3}$/);
  expect(srtLines[2]).toContain("Hello and welcome");

  expect(files.txt.trim().split("\n")).toHaveLength(4);

  expect(files.md.startsWith("# Summary")).toBe(true);
  expect(files.md).toContain("## Transcript");
  expect(files.md).toContain("- [00:07]");

  const json = JSON.parse(files.json);
  expect(json.id).toBe(id);
  expect(json.segments).toHaveLength(4);
  expect(json.summary).toContain("TL;DR");
});
