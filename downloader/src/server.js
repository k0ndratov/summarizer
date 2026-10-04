import http from "node:http";
import path from "node:path";
import { download } from "./download.js";

const PORT = Number(process.env.PORT ?? 3001);
const DATA_DIR = process.env.DATA_DIR ?? "/data";
const ID_RE = /^[A-Za-z0-9_-]{1,64}$/;
const FINISHED_TTL_MS = 60 * 60 * 1000; // forget finished jobs after an hour

function json(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (c) => (data += c));
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

// POST /download {url, id} → 202 {id, status: "running"}; the download runs in
// the background. GET /download/:id → {status: running|done|failed, path, chunks, error}.
export function createServer({ run = download } = {}) {
  const jobs = new Map();

  async function start(req, res) {
    let body;
    try {
      body = JSON.parse((await readBody(req)) || "{}");
    } catch {
      return json(res, 400, { error: "invalid JSON" });
    }
    const { url, id } = body;
    if (typeof url !== "string" || !/^https?:\/\//.test(url)) return json(res, 400, { error: "url must be an http(s) URL" });
    if (typeof id !== "string" || !ID_RE.test(id)) return json(res, 400, { error: "id must match [A-Za-z0-9_-]{1,64}" });
    if (jobs.get(id)?.status === "running") return json(res, 409, { error: `download ${id} is already running` });

    const job = { status: "running" };
    jobs.set(id, job);
    run({ url, target: path.join(DATA_DIR, `${id}.mp3`) })
      .then((result) => Object.assign(job, { status: "done", ...result }))
      .catch((e) => Object.assign(job, { status: "failed", error: e.message }))
      .finally(() => setTimeout(() => jobs.get(id) === job && jobs.delete(id), FINISHED_TTL_MS).unref());
    json(res, 202, { id, status: "running" });
  }

  return http.createServer(async (req, res) => {
    if (req.method === "GET" && req.url === "/health") return json(res, 200, { ok: true });
    if (req.method === "POST" && req.url === "/download") return start(req, res);

    const match = req.method === "GET" && req.url.match(/^\/download\/([A-Za-z0-9_-]+)$/);
    if (match) {
      const job = jobs.get(match[1]);
      return job ? json(res, 200, job) : json(res, 404, { error: "unknown download id" });
    }
    json(res, 404, { error: "not found" });
  });
}

if (import.meta.filename === process.argv[1]) {
  createServer().listen(PORT, () => console.log(`downloader listening on :${PORT}`));
}
