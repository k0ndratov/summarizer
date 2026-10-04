# Download → transcribe → summarize, updating Summary#status at each step.
# Transient errors (timeouts, rate limits) retry a few times; anything else
# marks the summary failed with the error message shown to the user.
class TranscribeJob < ApplicationJob
  queue_as :default

  rescue_from StandardError do |e|
    mark_failed(e)
  end

  retry_on Services::TransientError, wait: :polynomially_longer, attempts: 3 do |job, e|
    job.mark_failed(e)
  end

  def perform(summary_id)
    @summary = Summary.find(summary_id)
    return if @summary.finished?

    @summary.update!(status: :downloading, error: nil)
    audio_path = Services.downloader.call(url: @summary.source_url, id: @summary.id)
    @summary.update!(status: :transcribing, audio_path: audio_path)

    transcript = Services.transcriber.call(audio_path)
    @summary.update!(status: :summarizing, segments: transcript[:segments])
    File.delete(audio_path) if File.exist?(audio_path)

    summary_text = Services.summarizer.call(transcript[:segments])
    @summary.update!(status: :done, summary: summary_text, audio_path: nil)
  end

  def mark_failed(error)
    Rails.logger.error("TranscribeJob #{arguments.first}: #{error.class}: #{error.message}")
    @summary ||= Summary.find_by(id: arguments.first)
    @summary&.update!(status: :failed, error: error.message.truncate(1000))
  end
end
