require "test_helper"

class SummaryTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  test "status updates broadcast a replace of the summary partial" do
    s = Summary.create!(source_url: "https://drive.google.com/x")
    streams = capture_turbo_stream_broadcasts(s) { s.update!(status: :transcribing) }
    assert_equal 1, streams.size
    assert_equal "replace", streams.first["action"]
    assert_equal "summary_#{s.id}", streams.first["target"]
    assert_includes streams.first.to_html, 'data-status="transcribing"'
  end

  test "defaults to pending" do
    assert_predicate Summary.create!(source_url: "https://drive.google.com/x"), :pending?
  end

  test "rejects non-http URLs" do
    %w[ftp://x drive.google.com/x javascript:alert(1)].each do |url|
      s = Summary.new(source_url: url)
      assert_not s.valid?, url
    end
    assert_not Summary.new(source_url: nil).valid?
  end

  test "finished? only for terminal statuses" do
    assert Summary.new(status: :done).finished?
    assert Summary.new(status: :failed).finished?
    assert_not Summary.new(status: :summarizing).finished?
  end

  test "segments default to empty array and duration to 0" do
    s = Summary.new
    assert_equal [], s.segments
    assert_equal 0, s.duration
    s.segments = [ { "start" => 0.0, "end" => 4.5, "text" => "a" }, { "start" => 4.5, "end" => 9.1, "text" => "b" } ]
    assert_equal 9.1, s.duration
  end
end
