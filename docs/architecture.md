# Architecture

## 1. Structure — container diagram (C4 level 2)

Static view: deployable units and dependencies. No ordering.

```mermaid
flowchart TB
  user(["User<br/><i>submits Drive link,<br/>reads / downloads result</i>"])

  drive["Google Drive<br/><i>source video/audio</i>"]
  whisper["OpenAI Whisper API<br/><i>whisper-1, verbose_json</i>"]
  claude["Anthropic Claude API<br/><i>claude-sonnet-4-5</i>"]

  subgraph compose["docker compose — make start"]
    direction LR
    web["<b>web</b><br/>Rails 8, Puma, Solid Queue<br/><i>form · TranscribeJob · live result page · srt/txt/md/json</i>"]
    dl["<b>downloader</b><br/>Node.js, yt-dlp, ffmpeg<br/><i>POST /download: URL → mp3</i>"]
    db[("<b>SQLite</b><br/>storage/*.sqlite3<br/><i>summaries · queue · cable</i>")]
    media[("<b>media volume</b><br/>/data<br/><i>mp3 files</i>")]
  end

  user -- "HTTP + WebSocket (Turbo Streams)" --> web
  web -- "POST /download {url}" --> dl
  dl -- "yt-dlp" --> drive
  dl -- "writes mp3" --> media
  web -- "reads mp3" --> media
  web -- "read / write" --> db
  web -- "transcribe (HTTPS multipart)" --> whisper
  web -- "summarize (HTTPS)" --> claude

  classDef ext fill:#999,stroke:#666,color:#fff
  classDef c fill:#438dd5,stroke:#2e6295,color:#fff
  classDef person fill:#08427b,stroke:#052e56,color:#fff
  class drive,whisper,claude ext
  class web,dl,db,media c
  class user person
```

## 2. Behavior — sequence diagram, happy path

Dynamic view: one scenario, "submit URL → summary shown".

```mermaid
sequenceDiagram
  actor U as User (browser)
  participant C as web: SummariesController
  participant J as web: TranscribeJob (Solid Queue)
  participant DB as SQLite
  participant D as downloader
  participant V as /data volume
  participant W as OpenAI Whisper
  participant A as Anthropic Claude

  U->>C: POST /summaries {source_url}
  C->>DB: INSERT summaries (status=pending)
  C->>J: perform_later(summary_id)
  C-->>U: 302 → GET /summaries/:id
  U->>C: GET /summaries/:id
  C-->>U: page + turbo_stream_from summary

  J->>DB: status=downloading
  DB-->>U: Turbo broadcast (status)
  J->>D: POST /download {url, id}
  D->>D: yt-dlp -x --audio-format mp3
  D->>V: write /data/:id.mp3
  D-->>J: 200 {path}

  J->>DB: status=transcribing
  DB-->>U: Turbo broadcast
  J->>V: read /data/:id.mp3
  J->>W: POST /audio/transcriptions (verbose_json)
  W-->>J: {text, segments[start,end,text]}
  J->>DB: UPDATE segments

  J->>DB: status=summarizing
  DB-->>U: Turbo broadcast
  J->>A: POST /messages {transcript text}
  A-->>J: summary (markdown)
  J->>DB: UPDATE summary, status=done
  DB-->>U: Turbo broadcast (summary + transcript + download links)

  U->>C: GET /summaries/:id.srt | .txt | .md | .json
  C->>DB: SELECT segments, summary
  C-->>U: rendered file
```
