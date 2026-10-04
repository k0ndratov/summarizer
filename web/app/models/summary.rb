class Summary < ApplicationRecord
  STATUSES = %w[pending downloading transcribing summarizing done failed].freeze
  enum :status, STATUSES.index_by(&:itself), default: :pending

  validates :source_url, presence: true, format: { with: %r{\Ahttps?://\S+\z}, message: "must be an http(s) URL" }

  def finished? = done? || failed?

  def segments = super || []

  def duration = segments.last&.fetch("end", 0) || 0
end
