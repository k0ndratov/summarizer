require "test_helper"

class ExportersTest < ActiveSupport::TestCase
  SEGMENTS = [
    { "start" => 0.0, "end" => 4.8, "text" => "First line." },
    { "start" => 59.999, "end" => 65.4, "text" => "Across the minute." },
    { "start" => 3600.0, "end" => 3661.25, "text" => "Past an hour." }
  ].freeze

  setup do
    @summary = Summary.new(id: 7, source_url: "https://x.test/v", status: :done, segments: SEGMENTS, summary: "## TL;DR\nShort.")
  end

  test "srt blocks are indexed from 1 with comma-millisecond timestamps" do
    assert_equal <<~SRT, Exporters.render(@summary, :srt)
      1
      00:00:00,000 --> 00:00:04,800
      First line.

      2
      00:00:59,999 --> 00:01:05,400
      Across the minute.

      3
      01:00:00,000 --> 01:01:01,250
      Past an hour.
    SRT
  end

  test "txt is one segment per line" do
    assert_equal "First line.\nAcross the minute.\nPast an hour.\n", Exporters.render(@summary, :txt)
  end

  test "md has the summary then a timestamped transcript" do
    md = Exporters.render(@summary, :md)
    assert md.start_with?("# Summary\n")
    assert_includes md, "## TL;DR\nShort."
    assert_includes md, "- [00:59] Across the minute."
    assert_includes md, "- [1:00:00] Past an hour."
    assert md.index("## TL;DR") < md.index("## Transcript")
  end

  test "json round-trips segments and summary" do
    data = JSON.parse(Exporters.render(@summary, :json))
    assert_equal SEGMENTS, data["segments"]
    assert_equal "## TL;DR\nShort.", data["summary"]
    assert_equal 3661.25, data["duration"]
  end

  test "empty transcript exports without errors" do
    @summary.segments = []
    assert_equal "", Exporters.render(@summary, :srt)
    assert_equal "\n", Exporters.render(@summary, :txt)
  end
end
