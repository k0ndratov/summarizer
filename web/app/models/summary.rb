class Summary < ApplicationRecord
  STATUSES = %w[pending downloading transcribing summarizing done failed].freeze
  enum :status, STATUSES.index_by(&:itself), default: :pending

  validates :source_url, presence: true, format: { with: %r{\Ahttps?://\S+\z}, message: "must be an http(s) URL" }

  # Every update re-renders the summary partial over Action Cable so the show
  # page follows the job's progress without reloading (see turbo_stream_from in show).
  after_update_commit -> { broadcast_replace_to self }

  def finished? = done? || failed?

  def segments = super || []

  def duration = segments.last&.fetch("end", 0) || 0
end
