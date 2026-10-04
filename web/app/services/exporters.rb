# Renders a finished Summary into downloadable formats.
module Exporters
  FORMATS = {
    srt: { mime: "application/x-subrip", render: ->(s) { srt(s) } },
    txt: { mime: "text/plain", render: ->(s) { txt(s) } },
    md: { mime: "text/markdown", render: ->(s) { md(s) } },
    json: { mime: "application/json", render: ->(s) { json(s) } }
  }.freeze

  def self.render(summary, format) = FORMATS.fetch(format.to_sym)[:render].call(summary)
  def self.mime(format) = FORMATS.fetch(format.to_sym)[:mime]

  # SubRip: blocks of "index / start --> end / text / blank line".
  def self.srt(summary)
    summary.segments.each_with_index.map do |seg, i|
      "#{i + 1}\n#{Timestamp.srt(seg['start'])} --> #{Timestamp.srt(seg['end'])}\n#{seg['text']}\n"
    end.join("\n")
  end

  def self.txt(summary) = summary.segments.map { |seg| seg["text"] }.join("\n") + "\n"

  def self.md(summary)
    transcript = summary.segments.map { |seg| "- [#{Timestamp.clock(seg['start'])}] #{seg['text']}" }.join("\n")
    <<~MD
      # Summary

      Source: #{summary.source_url}

      #{summary.summary.to_s.strip}

      ## Transcript

      #{transcript}
    MD
  end

  def self.json(summary)
    JSON.pretty_generate(
      id: summary.id,
      source_url: summary.source_url,
      status: summary.status,
      duration: summary.duration,
      summary: summary.summary,
      segments: summary.segments,
      created_at: summary.created_at
    ) + "\n"
  end
end
