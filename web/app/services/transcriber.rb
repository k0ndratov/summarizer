# OpenAI whisper-1 with segment timestamps.
# Returns { language: "en", segments: [{ "start" => 0.0, "end" => 4.2, "text" => "..." }, ...] }
class Transcriber
  MAX_BYTES = 25.megabytes # hard limit of the Whisper API

  def initialize(client: OpenAI::Client.new(access_token: ENV.fetch("OPENAI_API_KEY"), request_timeout: 600))
    @client = client
  end

  def call(path)
    size = File.size(path)
    if size > MAX_BYTES
      raise Services::Error, "Audio is #{(size / 1.megabyte.to_f).round(1)} MB; Whisper accepts at most 25 MB"
    end

    response = File.open(path, "rb") do |file|
      @client.audio.transcribe(parameters: { model: "whisper-1", file: file, response_format: "verbose_json" })
    end

    { language: response["language"], segments: normalize(response.fetch("segments", [])) }
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::ServerError, Faraday::TooManyRequestsError => e
    raise Services::TransientError, "Whisper: #{e.message}"
  rescue Faraday::ClientError => e
    raise Services::Error, "Whisper: #{e.response&.dig(:body, 'error', 'message') || e.message}"
  end

  private

  def normalize(segments)
    segments.map { |s| { "start" => s["start"].to_f.round(3), "end" => s["end"].to_f.round(3), "text" => s["text"].to_s.strip } }
            .reject { |s| s["text"].empty? }
  end
end
