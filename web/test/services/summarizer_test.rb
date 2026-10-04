require "test_helper"

class SummarizerTest < ActiveSupport::TestCase
  class FakeMessages
    attr_reader :params
    def create(params)
      @params = params
      Struct.new(:content).new([ Struct.new(:text).new("## TL;DR\nfine"), Struct.new(:type).new("tool_use") ])
    end
  end

  setup do
    @messages = FakeMessages.new
    @client = Struct.new(:messages).new(@messages)
  end

  test "sends a timestamped transcript and returns the text blocks" do
    segments = [ { "start" => 0.0, "end" => 3.0, "text" => "Hi" }, { "start" => 65.5, "end" => 70.0, "text" => "Later" } ]
    assert_equal "## TL;DR\nfine", Summarizer.new(client: @client).call(segments)
    assert_equal "[00:00] Hi\n[01:05] Later", @messages.params[:messages].first[:content]
    assert_equal Summarizer::MODEL, @messages.params[:model]
  end

  test "refuses an empty transcript" do
    assert_raises(Services::Error) { Summarizer.new(client: @client).call([]) }
    assert_nil @messages.params
  end
end
