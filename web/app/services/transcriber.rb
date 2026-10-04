# OpenAI whisper-1 with segment timestamps, one request per audio chunk.
# Input: [{ path:, start: }, ...] from the downloader. Output:
# { language: "en", segments: [{ "start" => 0.0, "end" => 4.2, "text" => "..." }, ...] }
# with every timestamp shifted by its chunk's start, so the result is one
# continuous timeline.
class Transcriber
  MAX_BYTES = 25.megabytes # hard limit of the Whisper API

  def initialize(client: OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"), request_timeout: 600))
    @client = client
  end

  def call(chunks)
    language = nil
    segments = chunks.flat_map do |chunk|
      response = transcribe(chunk[:path])
      language ||= response["language"]
      normalize(response.fetch("segments", []), chunk[:start].to_f)
    end
    { language: language, segments: segments }
  end

  private

  def transcribe(path)
    size = File.size(path)
    if size > MAX_BYTES
      raise Services::Error, "Audio chunk is #{(size / 1.megabyte.to_f).round(1)} MB; Whisper accepts at most 25 MB"
    end

    File.open(path, "rb") do |file|
      @client.audio.transcribe(parameters: { model: "whisper-1", file: file, response_format: "verbose_json" })
    end
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ServerError, Faraday::TooManyRequestsError => e
    raise Services::TransientError, "Whisper: #{e.message}"
  rescue Faraday::ClientError => e
    raise Services::Error, "Whisper: #{api_error_message(e)}"
  end

  def normalize(segments, offset)
    segments.map { |s| { "start" => (s["start"].to_f + offset).round(3), "end" => (s["end"].to_f + offset).round(3), "text" => s["text"].to_s.strip } }
            .reject { |s| s["text"].empty? }
  end

  # Faraday leaves the error body as a raw JSON string; OpenAI puts the reason in error.message.
  def api_error_message(error)
    body = error.response&.dig(:body)
    body = JSON.parse(body) if body.is_a?(String)
    body.dig("error", "message") || error.message
  rescue JSON::ParserError, TypeError
    error.message
  end
end
