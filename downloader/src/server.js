import http from "node:http";

const PORT = Number(process.env.PORT ?? 3001);

function json(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

export function createServer() {
  return http.createServer((req, res) => {
    if (req.method === "GET" && req.url === "/health") return json(res, 200, { ok: true });
    json(res, 404, { error: "not found" });
  });
}

if (import.meta.filename === process.argv[1]) {
  createServer().listen(PORT, () => console.log(`downloader listening on :${PORT}`));
}
