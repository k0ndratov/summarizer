# Fixture-backed stand-ins used when FAKE_SERVICES=true. Same interfaces as the
# real classes; each step sleeps FAKE_DELAY seconds (default 0.3) so status
# transitions are observable in the UI and in e2e tests.
module FakeServices
  FIXTURES = Rails.root.join("test/fixtures/files")

  def self.delay = sleep(ENV.fetch("FAKE_DELAY", "0.3").to_f)

  class Downloader
    # A URL containing "fail" simulates yt-dlp rejecting the link.
    def call(url:, id:)
      FakeServices.delay
      raise Services::Error, "Downloader: Unable to download: #{url}" if url.include?("fail")

      target = File.join(ENV.fetch("DATA_DIR", "/data"), "#{id}.mp3")
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(FIXTURES.join("sample.mp3"), target)
      { path: target, chunks: [ { path: target, start: 0.0 } ] }
    end
  end

  class Transcriber
    def call(_chunks)
      FakeServices.delay
      { language: "en", segments: JSON.parse(FIXTURES.join("segments.json").read) }
    end
  end

  class Summarizer
    def call(_segments)
      FakeServices.delay
      FIXTURES.join("summary.md").read
    end
  end
end
