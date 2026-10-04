import { spawn } from "node:child_process";
import { stat } from "node:fs/promises";

// Whisper rejects uploads over 25 MB; chunks are cut below that with margin.
const DEFAULT_CHUNK_BYTES = 20 * 1024 * 1024;

// Downloads `url` with yt-dlp, converts the audio track to mp3 at `target`, and
// splits it into chunks under `chunkBytes` when needed.
// Resolves { path, chunks: [{ path, start }] } where `start` is the chunk's
// offset in seconds within the full file. Rejects with yt-dlp's last stderr line.
export async function download({ url, target, chunkBytes = Number(process.env.CHUNK_BYTES) || DEFAULT_CHUNK_BYTES }) {
  await run("yt-dlp", [
    "--no-playlist",
    "--no-cache-dir",
    "--extract-audio",
    "--audio-format", "mp3",
    "--audio-quality", "5",
    "--force-overwrites",
    "--output", target.replace(/\.mp3$/, ".%(ext)s"),
    url,
  ]);

  let size;
  try {
    ({ size } = await stat(target));
  } catch {
    throw new Error("yt-dlp finished but no mp3 was produced");
  }

  const chunks = size > chunkBytes ? await split(target, size, chunkBytes) : [{ path: target, start: 0 }];
  return { path: target, chunks };
}

// Cuts `target` into pieces of roughly `chunkBytes` by time, without re-encoding.
async function split(target, size, chunkBytes) {
  const total = await duration(target);
  const seconds = Math.max(1, Math.floor(total * (chunkBytes / size) * 0.95));
  const pattern = target.replace(/\.mp3$/, ".part%03d.mp3");
  await run("ffmpeg", ["-v", "error", "-y", "-i", target, "-f", "segment", "-segment_time", String(seconds), "-c", "copy", pattern]);

  const chunks = [];
  let start = 0;
  for (let i = 0; ; i++) {
    const path = pattern.replace("%03d", String(i).padStart(3, "0"));
    try {
      await stat(path);
    } catch {
      break;
    }
    chunks.push({ path, start: Math.round(start * 1000) / 1000 });
    start += await duration(path);
  }
  return chunks;
}

async function duration(path) {
  const out = await run("ffprobe", ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]);
  return Number.parseFloat(out) || 0;
}

function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (c) => (stdout += c));
    proc.stderr.on("data", (c) => (stderr += c));
    proc.on("error", (e) => reject(new Error(`${cmd} failed to start: ${e.message}`)));
    proc.on("close", (code) => {
      if (code !== 0) return reject(new Error(lastLine(stderr) || `${cmd} exited with ${code}`));
      resolve(stdout);
    });
  });
}

function lastLine(s) {
  return s.trim().split("\n").filter(Boolean).at(-1)?.replace(/^ERROR:\s*/, "") ?? "";
}
