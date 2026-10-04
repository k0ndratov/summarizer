# summorization

Paste a public Google Drive link to a video or audio file → get a timestamped transcript and a summary. Download as `srt`, `txt`, `md`, or `json`.

## Run

```sh
cp .env.example .env   # add OPENAI_API_KEY and ANTHROPIC_API_KEY
make start
```

Open http://localhost:3000.

## Test

```sh
make test   # Rails tests, downloader tests, Playwright e2e
```

## How it works

Two containers started by `docker compose`:

- `web` — Rails 8. Form, background job (Solid Queue), live status page (Turbo Streams), exports.
- `downloader` — Node.js + `yt-dlp` + `ffmpeg`. Turns a Drive link into an mp3 on a shared volume.

Transcription: OpenAI `whisper-1` with segment timestamps. Summarization: Anthropic Claude.

Diagrams and details: [docs/architecture.md](docs/architecture.md). Plan: [docs/plan.md](docs/plan.md).
