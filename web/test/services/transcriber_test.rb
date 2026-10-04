require "test_helper"

class TranscriberTest < ActiveSupport::TestCase
  # Returns a canned verbose_json per call, records the parameters it was given.
  class FakeAudio
    attr_reader :calls
    def initialize(responses) = (@responses = responses.dup; @calls = [])
    def transcribe(parameters:) = (@calls << parameters; @responses.shift)
  end

  setup do
    @paths = 2.times.map { |i| Rails.root.join("tmp/transcriber_test_#{i}.mp3").to_s.tap { |p| File.write(p, "x") } }
  end

  teardown { @paths.each { |p| File.delete(p) if File.exist?(p) } }

  def transcriber(*responses)
    @audio = FakeAudio.new(responses)
    Transcriber.new(client: Struct.new(:audio).new(@audio))
  end

  test "maps verbose_json to trimmed segments, dropping empty ones" do
    t = transcriber("language" => "en", "segments" => [
      { "id" => 0, "start" => 0.0, "end" => 4.123456, "text" => "  Hello there. ", "tokens" => [ 1, 2 ] },
      { "id" => 1, "start" => 4.123456, "end" => 6.0, "text" => "   " }
    ])
    result = t.call([ { path: @paths[0], start: 0.0 } ])
    assert_equal "en", result[:language]
    assert_equal [ { "start" => 0.0, "end" => 4.123, "text" => "Hello there." } ], result[:segments]
    assert_equal "whisper-1", @audio.calls.first[:model]
    assert_equal "verbose_json", @audio.calls.first[:response_format]
  end

  test "shifts each chunk's timestamps by its start so the timeline is continuous" do
    t = transcriber(
      { "language" => "ru", "segments" => [ { "start" => 0.0, "end" => 3.0, "text" => "a" }, { "start" => 3.0, "end" => 5.9, "text" => "b" } ] },
      { "language" => "ru", "segments" => [ { "start" => 0.0, "end" => 2.5, "text" => "c" } ] }
    )
    result = t.call([ { path: @paths[0], start: 0.0 }, { path: @paths[1], start: 600.25 } ])
    assert_equal [
      { "start" => 0.0, "end" => 3.0, "text" => "a" },
      { "start" => 3.0, "end" => 5.9, "text" => "b" },
      { "start" => 600.25, "end" => 602.75, "text" => "c" }
    ], result[:segments]
    assert result[:segments].each_cons(2).all? { |x, y| x["end"] <= y["start"] }
    assert_equal 2, @audio.calls.size
  end

  test "rejects a chunk over 25 MB before calling the API" do
    t = transcriber
    File.stub(:size, 26.megabytes) do
      e = assert_raises(Services::Error) { t.call([ { path: @paths[0], start: 0.0 } ]) }
      assert_match(/26\.0 MB.*25 MB/, e.message)
    end
    assert_empty @audio.calls
  end
end
