require "test_helper"

class TranscriberTest < ActiveSupport::TestCase
  class FakeAudio
    attr_reader :params
    def transcribe(parameters:) = (@params = parameters; RESPONSE)
  end
  RESPONSE = {
    "language" => "en",
    "segments" => [
      { "id" => 0, "start" => 0.0, "end" => 4.123456, "text" => "  Hello there. ", "tokens" => [ 1, 2 ] },
      { "id" => 1, "start" => 4.123456, "end" => 6.0, "text" => "   " }
    ]
  }.freeze

  setup do
    @audio = FakeAudio.new
    @client = Struct.new(:audio).new(@audio)
    @path = Rails.root.join("tmp/transcriber_test.mp3").to_s
    File.write(@path, "x")
  end

  teardown { File.delete(@path) if File.exist?(@path) }

  test "maps verbose_json to trimmed segments, dropping empty ones" do
    result = Transcriber.new(client: @client).call(@path)
    assert_equal "en", result[:language]
    assert_equal [ { "start" => 0.0, "end" => 4.123, "text" => "Hello there." } ], result[:segments]
    assert_equal "whisper-1", @audio.params[:model]
    assert_equal "verbose_json", @audio.params[:response_format]
  end

  test "rejects files over 25 MB before calling the API" do
    File.stub(:size, 26.megabytes) do
      e = assert_raises(Services::Error) { Transcriber.new(client: @client).call(@path) }
      assert_match(/26\.0 MB.*25 MB/, e.message)
    end
    assert_nil @audio.params
  end
end
