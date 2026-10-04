# Resolves the three external-facing services. With FAKE_SERVICES=true
# (e2e, demos) fixtures are returned instead of calling the downloader,
# OpenAI, or Anthropic.
module Services
  # Permanent failure: bad input, unsupported file, provider rejected the request.
  class Error < StandardError; end
  # Temporary failure worth retrying: timeouts, connection refused, rate limits.
  class TransientError < Error; end

  def self.fake? = ENV["FAKE_SERVICES"] == "true"

  def self.downloader = fake? ? FakeServices::Downloader.new : DownloaderClient.new
  def self.transcriber = fake? ? FakeServices::Transcriber.new : Transcriber.new
  def self.summarizer = fake? ? FakeServices::Summarizer.new : Summarizer.new
end
