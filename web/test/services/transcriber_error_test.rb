require "test_helper"

class TranscriberErrorTest < ActiveSupport::TestCase
  setup do
    @path = Rails.root.join("tmp/transcriber_error_test.mp3").to_s
    File.write(@path, "x")
  end

  teardown { File.delete(@path) if File.exist?(@path) }

  def transcriber_raising(error)
    audio = Object.new
    audio.define_singleton_method(:transcribe) { |**| raise error }
    Transcriber.new(client: Struct.new(:audio).new(audio))
  end

  test "surfaces OpenAI's message from a raw JSON error body" do
    error = Faraday::UnauthorizedError.new("the server responded with status 401",
      { status: 401, body: '{"error":{"message":"Incorrect API key provided","type":"invalid_request_error"}}' })
    e = assert_raises(Services::Error) { transcriber_raising(error).call(@path) }
    assert_equal "Whisper: Incorrect API key provided", e.message
  end

  test "falls back to the exception message when the body is not JSON" do
    error = Faraday::BadRequestError.new("the server responded with status 400", { status: 400, body: "<html>nope</html>" })
    e = assert_raises(Services::Error) { transcriber_raising(error).call(@path) }
    assert_equal "Whisper: the server responded with status 400", e.message
  end

  test "server errors are transient" do
    error = Faraday::ServerError.new("the server responded with status 502", { status: 502, body: "" })
    assert_raises(Services::TransientError) { transcriber_raising(error).call(@path) }
  end
end
