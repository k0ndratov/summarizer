# Implementation plan

Each step ends in a runnable, committed, pushed state. Design: `.ai/stack.md`, `docs/architecture.md`.

## Part A — only you can do this (accounts, secrets, remotes)

Everything else is blocked on nothing but these. Do them first, in any order.

- [ ] **OpenAI account** → API key with billing enabled (Whisper is pay-per-minute)
- [ ] **Anthropic account** → API key
- [ ] Put both keys into `.env` (still placeholders) locally (file is git-ignored; never paste keys into chat)
- [x] **GitHub repo**: create empty public repo `summorization`; note the remote URL
- [x] Git identity on this machine: `git config --global user.name / user.email`
- [x] Push auth working: `gh auth login` or SSH key added to GitHub
- [x] Docker daemon running and `docker compose version` works; `make` installed
- [x] Test link → `TEST_DRIVE_URL` in `.env` (18 s mp4, public, verified with `yt-dlp --simulate`)

**Acceptance:**
```sh
grep -c 'sk-' .env                      # → 2  (both keys present)
docker compose version && make --version
git ls-remote origin                    # lists refs, no auth error
yt-dlp --simulate "$TEST_DRIVE_URL"        # prints title, no "private"/"403" error (or trust step 2 to verify)
```

## Part B — autonomous (agent implements, you review)

Needs from Part A: nothing for steps 1–3; `.env` keys and the test Drive link for steps 2 and 4+; push access for every commit.

**Test layers** (all runnable after any change, `make test` runs all three):
- Unit/controller/job — Rails Minitest (`web/test`), Node `node:test` (`downloader/test`). Fast, external services mocked.
- **E2E — Playwright** (`e2e/`, TypeScript, `make e2e`). Drives the real stack in the browser with `FAKE_SERVICES=true`: the three external edges (downloader → Drive, Whisper, Claude) return fixtures; job, queue, Turbo Streams, exports are real. Runs in ~10 s, no API keys, no network. Grows one spec per stage from stage 3 on.
- Manual real-API run — once, before submission (stage 7).

### 1. Repo skeleton
- [x] `git init`, `.gitignore` (`.env`, `storage/`, `node_modules/`, `tmp/`, `log/`)
- [x] `.env.example`: `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` (secrets only)
- [x] `docker-compose.yml`: services `web` (:3000) and `downloader` (:3001), volume `media:/data`, `env_file: .env`, `web.environment.DOWNLOADER_URL=http://downloader:3001`
- [x] `Makefile`: `start`, `stop`, `logs`, `shell`, `test` (rails + node + e2e), `e2e`
- [x] `README.md`: what it is, `make start`, open http://localhost:3000, `make test`
- [x] Commit, push

**Acceptance:**
```sh
make start                              # both images build, no errors
docker compose ps                       # web and downloader "running"
curl -s localhost:3001/health           # → {"ok":true}
curl -sI localhost:3000 | head -1       # → HTTP/1.1 200
git status --short                      # empty; git log shows the push
```

### 2. Downloader service (`downloader/`)
- [x] `Dockerfile`: node:22-alpine + `ffmpeg` + `yt-dlp`
- [x] `server.js` (Express/Fastify): `GET /health`, `POST /download {url, id}`
- [x] Spawn `yt-dlp -x --audio-format mp3 -o /data/<id>.%(ext)s <url>`; await exit
- [x] Response: `200 {path: "/data/<id>.mp3"}`; `422 {error}` on yt-dlp failure; `400` on bad input
- [x] Commit, push

**Acceptance:**
```sh
curl -s -X POST localhost:3001/download -H 'content-type: application/json' \
  -d '{"url":"$TEST_DRIVE_URL","id":"test"}'            # → {"path":"/data/test.mp3"}
docker compose exec downloader ffprobe /data/test.mp3  # shows mp3 stream, duration > 0
curl -s -X POST localhost:3001/download -H 'content-type: application/json' \
  -d '{"url":"https://example.com/nope","id":"bad"}' -w '%{http_code}'   # → 422 + {"error":...}
curl -s -X POST localhost:3001/download -d '{}' -w '%{http_code}'        # → 400
```
Test: `downloader/test/server.test.js` (node:test) — 400 on missing fields, 422 when yt-dlp exits non-zero (stub spawn), 200 + path on success.

### 3. Rails app skeleton (`web/`)
- [x] `rails new web --database=sqlite3 --css=tailwind` (Solid Queue/Cable included)
- [x] `Dockerfile` (dev-friendly: no asset precompile step needed), add to compose
- [x] `database.yml`: `primary`, `queue`, `cable` SQLite files under `storage/`
- [x] `development.rb`: `queue_adapter = :solid_queue`; `SOLID_QUEUE_IN_PUMA=true` in compose
- [x] `FAKE_SERVICES` env: `config/initializers/services.rb` picks `Fake*` or real service classes; compose has a `web-test` profile with `FAKE_SERVICES=true`
- [x] `e2e/`: `package.json` (`@playwright/test`), `playwright.config.ts` (`baseURL: http://localhost:3000`, `webServer` → `docker compose --profile test up`), `make e2e`
- [x] Model `Summary`: `source_url`, `status` (enum: pending/downloading/transcribing/summarizing/done/failed), `error`, `audio_path`, `segments` (json), `summary` (text)
- [x] `SummariesController`: `new`, `create`, `show`; routes; root → `summaries#new`
- [x] Views: form with URL input; show page with status badge
- [x] `create` enqueues `TranscribeJob.perform_later(summary.id)` and redirects to `show`
- [x] Commit, push

**Acceptance:**
```sh
docker compose exec web bin/rails db:prepare && docker compose exec web bin/rails test   # green
# browser: http://localhost:3000 → paste URL → submit → redirected to /summaries/1 showing "pending"
docker compose exec web bin/rails runner 'p Summary.last.slice(:id, :status, :source_url)'
# → {"id"=>1, "status"=>"pending", "source_url"=>"https://..."}
docker compose exec web bin/rails runner 'p SolidQueue::Job.count'   # → 1 (job enqueued)
```
Tests: `test/models/summary_test.rb` (status enum, url presence/format validation); `test/controllers/summaries_controller_test.rb` (`create` inserts row, enqueues `TranscribeJob`, redirects; invalid URL re-renders form).
E2E `e2e/submit.spec.ts`: home shows form → fill URL → submit → URL matches `/summaries/\d+` → `[data-status]` text is `pending`; empty/invalid URL → stays on form, error visible.

### 4. Pipeline job (`TranscribeJob`)
- [x] `app/services/downloader_client.rb`: `POST #{DOWNLOADER_URL}/download`, `read_timeout: 600`, raises `DownloaderClient::Error`
- [x] `app/services/transcriber.rb`: `ruby-openai` gem, `audio.transcribe(model: "whisper-1", response_format: "verbose_json")`, returns `segments`
- [x] `app/services/summarizer.rb`: `anthropic` gem, `messages.create(model: "claude-sonnet-4-5", ...)` with a summarization prompt, returns markdown
- [x] Job: update `status` before each step; on exception set `status: failed`, `error: message`
- [x] Reject audio > 25 MB with a clear error (chunking: step 8)
- [x] `retry_on` network/timeout errors, 3 attempts
- [x] Commit, push

**Acceptance:**
```sh
docker compose exec web bin/rails runner 'TranscribeJob.perform_now(Summary.create!(source_url: "$TEST_DRIVE_URL").id)'
docker compose exec web bin/rails runner 's=Summary.last; p s.status, s.segments.size, s.summary[0,200]'
# → "done", N > 0, non-empty summary text
docker compose exec web bin/rails runner 'TranscribeJob.perform_now(Summary.create!(source_url: "https://example.com/nope").id); p Summary.last.slice(:status, :error)'
# → {"status"=>"failed", "error"=>"Downloader: ..."}
```
Tests (`test/jobs/transcribe_job_test.rb`, services stubbed with Minitest mocks): status sequence pending→downloading→transcribing→summarizing→done; downloader error → `failed` + `error` set; Whisper response mapping to `segments`; file > 25 MB → `failed` without calling Whisper.
Fakes for E2E: `FakeDownloaderClient` (copies `test/fixtures/files/sample.mp3` to `/data/<id>.mp3`; URL containing `fail` raises), `FakeTranscriber` (returns `fixtures/segments.json`), `FakeSummarizer` (returns `fixtures/summary.md`), each with a 300 ms sleep so status transitions are observable.
E2E `e2e/pipeline.spec.ts`: submit → page reaches `done` (no reload; `page.on('framenavigated')` count stays 1) → summary heading and ≥ 1 transcript row visible; submit URL containing `fail` → page reaches `failed` with error text.

### 5. Live status + result page
- [x] `turbo_stream_from @summary` in `show`; `broadcasts_refreshes` (or `after_update_commit` broadcast) in model
- [x] `_summary.html.erb` partial: status, error, summary (markdown → HTML via `redcarpet`/`commonmarker`), transcript table with `mm:ss` timestamps
- [x] Verify Solid Cable works inside Docker (Action Cable mounted, `config/cable.yml` → `solid_cable`)
- [x] Commit, push

**Acceptance:**
```sh
# browser: submit URL, do NOT reload. Status badge changes pending → downloading → transcribing → summarizing → done
# on its own; summary and transcript appear. DevTools → Network → WS: one /cable connection, frames arriving.
docker compose exec web bin/rails runner 'p SolidCable::Message.count'   # > 0 (broadcasts went through)
```
Test: `test/models/summary_test.rb` — `assert_turbo_stream_broadcasts(summary)` on status update (turbo-rails test helper).
E2E `e2e/live-status.spec.ts`: after submit, observe `[data-status]` with `MutationObserver` (via `page.evaluate`), collect values until `done`; assert the ordered sequence `pending, downloading, transcribing, summarizing, done`; assert a WebSocket to `/cable` was opened (`page.on('websocket')`).

### 6. Exports
- [x] `show` responds to `.srt`, `.txt`, `.md`, `.json` (`respond_to` + `send_data`)
- [x] `app/services/exporters/`: `srt` (index, `HH:MM:SS,mmm --> ...`, text), `txt` (plain transcript), `md` (summary + timestamped transcript), `json` (raw row)
- [x] Download links on the result page
- [x] Commit, push

**Acceptance:**
```sh
ID=1
curl -s localhost:3000/summaries/$ID.srt | head -4     # → "1", "00:00:00,000 --> 00:00:04,800", text, blank
curl -s localhost:3000/summaries/$ID.txt | wc -w       # > 0
curl -s localhost:3000/summaries/$ID.md | head -1      # → "# Summary"
curl -s localhost:3000/summaries/$ID.json | jq '.segments | length'   # > 0
curl -sI localhost:3000/summaries/$ID.srt | grep -i content-disposition   # attachment; filename=...
ffmpeg -i /dev/null -i summary.srt -c:s srt out.srt 2>&1 | grep -ci error   # 0: srt parses
```
Tests (`test/services/exporters/*_test.rb`, fixed `segments` input): srt timestamp formatting (`HH:MM:SS,mmm`), sequential indices, boundary at 59.999 s / 1 h; txt joins segments; md contains summary + `[mm:ss]` lines; json round-trips.
E2E `e2e/exports.spec.ts`: on a `done` page, click each of the 4 links → `page.waitForEvent('download')` → filename ends with `.srt/.txt/.md/.json`; read content: srt first line `1`, second matches `\d\d:\d\d:\d\d,\d{3} --> `; json parses with `segments.length > 0`.

### 7. Polish and submission
- [x] `index` page listing past summaries
- [x] Delete mp3 after successful transcription
- [x] `README.md`: screenshots, env vars, architecture link, limitations (public Drive links only, 25 MB)
- [ ] Fresh clone test: `git clone … && cp .env.example .env && make start && make test`
- [x] `make e2e` in CI: `.github/workflows/ci.yml` runs rails test, node test, playwright (fake services) on every push
- [ ] Final push

**Acceptance:**
```sh
cd /tmp && git clone <repo url> fresh && cd fresh && cp .env.example .env   # fill keys
make start                                  # from zero to running, no manual steps
# browser: full flow on the test link → done, 4 downloads work
make test                                   # rails + node + playwright, all green
docker compose exec downloader ls /data     # mp3 removed after done
git log --oneline | wc -l                   # ≥ 7 commits (one per step)
# GitHub → Actions tab: latest run green
```

### 8. Optional (if time allows)
- [ ] Chunk audio > 25 MB with `ffmpeg -f segment`, offset timestamps, concatenate
- [ ] Downloader async mode (job id + poll) instead of long sync request

**Acceptance (if done):** 30+ min file → `done`, timestamps monotonic across chunk boundaries (`segments.each_cons(2).all? { |a,b| a["end"] <= b["start"] }`).
