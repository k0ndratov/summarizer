# Claude summary of a timestamped transcript. Returns markdown.
class Summarizer
  MODEL = "claude-sonnet-4-5"
  MAX_TOKENS = 1500

  SYSTEM = <<~PROMPT.freeze
    You summarize transcripts of videos. Each line is "[mm:ss] text".
    Answer in the language of the transcript, in Markdown, with these sections:
    ## TL;DR — 2-3 sentences.
    ## Key points — bullet list; reference timestamps like [mm:ss] where useful.
    ## Conclusion — one short paragraph.
    Do not invent facts that are not in the transcript.
  PROMPT

  def initialize(client: Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"), max_retries: 2))
    @client = client
  end

  def call(segments)
    raise Services::Error, "Nothing to summarize: transcript is empty" if segments.empty?

    response = @client.messages.create(
      model: MODEL,
      max_tokens: MAX_TOKENS,
      system: SYSTEM,
      messages: [ { role: "user", content: transcript_text(segments) } ]
    )
    response.content.filter_map { |block| block.text if block.respond_to?(:text) }.join("\n").strip
  rescue Anthropic::Errors::APIConnectionError, Anthropic::Errors::RateLimitError, Anthropic::Errors::InternalServerError => e
    raise Services::TransientError, "Claude: #{e.message}"
  rescue Anthropic::Errors::APIError => e
    raise Services::Error, "Claude: #{e.message}"
  end

  private

  def transcript_text(segments)
    segments.map { |s| "[#{Timestamp.clock(s['start'])}] #{s['text']}" }.join("\n")
  end
end
