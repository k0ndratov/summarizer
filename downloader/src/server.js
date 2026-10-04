import http from "node:http";
import path from "node:path";
import { download } from "./download.js";

const PORT = Number(process.env.PORT ?? 3001);
const DATA_DIR = process.env.DATA_DIR ?? "/data";
const ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

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

async function handleDownload(req, res, run) {
  let body;
  try {
    body = JSON.parse((await readBody(req)) || "{}");
  } catch {
    return json(res, 400, { error: "invalid JSON" });
  }
  const { url, id } = body;
  if (typeof url !== "string" || !/^https?:\/\//.test(url)) return json(res, 400, { error: "url must be an http(s) URL" });
  if (typeof id !== "string" || !ID_RE.test(id)) return json(res, 400, { error: "id must match [A-Za-z0-9_-]{1,64}" });

  const target = path.join(DATA_DIR, `${id}.mp3`);
  try {
    await run({ url, target });
    return json(res, 200, { path: target });
  } catch (e) {
    return json(res, 422, { error: e.message });
  }
}

export function createServer({ run = download } = {}) {
  return http.createServer(async (req, res) => {
    if (req.method === "GET" && req.url === "/health") return json(res, 200, { ok: true });
    if (req.method === "POST" && req.url === "/download") return handleDownload(req, res, run);
    json(res, 404, { error: "not found" });
  });
}

if (import.meta.filename === process.argv[1]) {
  createServer().listen(PORT, () => console.log(`downloader listening on :${PORT}`));
}
