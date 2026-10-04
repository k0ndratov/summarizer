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

const poll = async (base, id) => {
  for (let i = 0; i < 50; i++) {
    const job = await (await fetch(`${base}/download/${id}`)).json();
    if (job.status !== "running") return job;
    await new Promise((r) => setTimeout(r, 10));
  }
  throw new Error("still running");
};

test("GET /health", async () => {
  await withServer(null, async (base) => {
    const res = await fetch(`${base}/health`);
    assert.equal(res.status, 200);
    assert.deepEqual(await res.json(), { ok: true });
  });
});

test("POST /download → 202, then GET reports done with path and chunks", async () => {
  const calls = [];
  const result = { path: "/data/42.mp3", chunks: [{ path: "/data/42.part000.mp3", start: 0 }, { path: "/data/42.part001.mp3", start: 600.5 }] };
  await withServer(async (a) => { calls.push(a); return result; }, async (base) => {
    const res = await post(base, { url: "https://drive.google.com/file/d/abc/view", id: "42" });
    assert.equal(res.status, 202);
    assert.deepEqual(await res.json(), { id: "42", status: "running" });
    assert.deepEqual(calls, [{ url: "https://drive.google.com/file/d/abc/view", target: "/data/42.mp3" }]);

    assert.deepEqual(await poll(base, "42"), { status: "done", ...result });
  });
});

test("GET reports running while the download is in flight, then failed with the message", async () => {
  let fail;
  const pending = new Promise((_, reject) => (fail = reject));
  await withServer(() => pending, async (base) => {
    await post(base, { url: "https://example.com/nope", id: "bad" });
    assert.deepEqual(await (await fetch(`${base}/download/bad`)).json(), { status: "running" });

    fail(new Error("Unable to extract"));
    assert.deepEqual(await poll(base, "bad"), { status: "failed", error: "Unable to extract" });
  });
});

test("a second POST for a running id is refused with 409", async () => {
  await withServer(() => new Promise(() => {}), async (base) => {
    await post(base, { url: "https://x", id: "dup" });
    const res = await post(base, { url: "https://x", id: "dup" });
    assert.equal(res.status, 409);
  });
});

test("GET for an unknown id → 404", async () => {
  await withServer(null, async (base) => {
    assert.equal((await fetch(`${base}/download/nope`)).status, 404);
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
