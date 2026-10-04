import { spawn } from "node:child_process";
import { stat } from "node:fs/promises";

// Downloads `url` with yt-dlp and converts the audio track to mp3 at `target`.
// Resolves when the file exists; rejects with yt-dlp's last stderr line otherwise.
export function download({ url, target }) {
  const args = [
    "--no-playlist",
    "--extract-audio",
    "--audio-format", "mp3",
    "--audio-quality", "5",
    "--force-overwrites",
    "--output", target.replace(/\.mp3$/, ".%(ext)s"),
    url,
  ];

  return new Promise((resolve, reject) => {
    const proc = spawn("yt-dlp", args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    proc.stderr.on("data", (c) => (stderr += c));
    proc.on("error", (e) => reject(new Error(`yt-dlp failed to start: ${e.message}`)));
    proc.on("close", async (code) => {
      if (code !== 0) return reject(new Error(lastLine(stderr) || `yt-dlp exited with ${code}`));
      try {
        await stat(target);
        resolve(target);
      } catch {
        reject(new Error("yt-dlp finished but no mp3 was produced"));
      }
    });
  });
}

function lastLine(s) {
  return s.trim().split("\n").filter(Boolean).at(-1)?.replace(/^ERROR:\s*/, "") ?? "";
}
