import { test } from "node:test";
import assert from "node:assert/strict";
import { createServer } from "../src/server.js";

async function withServer(run, fn) {
  const server = createServer({ run });
  await new Promise((r) => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}`;
  try {
    await fn(base);
  } finally {
    server.close();
  }
}

const post = (base, body) =>
  fetch(`${base}/download`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

test("GET /health", async () => {
  await withServer(null, async (base) => {
    const res = await fetch(`${base}/health`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { ok: true });
  });
});

test("POST /download → 200 with path on success", async () => {
  const calls = [];
  await withServer(async (a) => calls.push(a), async (base) => {
    const res = await post(base, { url: "https://drive.google.com/file/d/abc/view", id: "42" });
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { path: "/data/42.mp3" });
    assert.deepEqual(calls, [{ url: "https://drive.google.com/file/d/abc/view", target: "/data/42.mp3" }]);
  });
});

test("POST /download → 422 with yt-dlp error message", async () => {
  await withServer(async () => { throw new Error("Unable to extract"); }, async (base) => {
    const res = await post(base, { url: "https://example.com/nope", id: "bad" });
    assert.equal(res.status, 422);
    assert.deepEqual(await res.json(), { error: "Unable to extract" });
  });
});

test("POST /download → 400 on bad input, never runs yt-dlp", async () => {
  let ran = false;
  await withServer(async () => { ran = true; }, async (base) => {
    for (const body of [
      "{",
      {},
      { url: "ftp://x", id: "1" },
      { url: "https://x", id: "../etc/passwd" },
      { url: "https://x", id: "" },
    ]) {
      const res = await post(base, body);
      assert.equal(res.status, 400, JSON.stringify(body));
    }
    assert.equal(ran, false);
  });
});
