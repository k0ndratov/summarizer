require "test_helper"

class TranscribeJobTest < ActiveJob::TestCase
  SEGMENTS = [ { "start" => 0.0, "end" => 2.5, "text" => "hi" }, { "start" => 2.5, "end" => 5.0, "text" => "bye" } ].freeze

  setup do
    @summary = Summary.create!(source_url: "https://drive.google.com/file/d/abc/view")
    @audio = Rails.root.join("tmp/test_audio_#{@summary.id}.mp3").to_s
    @chunk = Rails.root.join("tmp/test_audio_#{@summary.id}.part000.mp3").to_s
    [ @audio, @chunk ].each { |p| File.write(p, "x") }
    @download = { path: @audio, chunks: [ { path: @chunk, start: 0.0 } ] }
  end

  teardown { [ @audio, @chunk ].each { |p| File.delete(p) if File.exist?(p) } }

  # Stubs Services.* with lambdas; records the status seen at each call.
  def run_with(downloader: ->(**) { @download }, transcriber: ->(_) { { language: "en", segments: SEGMENTS } }, summarizer: ->(_) { "## TL;DR\nok" })
    seen = []
    summary = @summary
    service = ->(fn) { svc = Object.new; svc.define_singleton_method(:call) { |*a, **kw| seen << summary.reload.status; fn.call(*a, **kw) }; -> { svc } }
    Services.stub(:downloader, service.call(downloader)) do
      Services.stub(:transcriber, service.call(transcriber)) do
        Services.stub(:summarizer, service.call(summarizer)) do
          TranscribeJob.perform_now(@summary.id)
        end
      end
    end
    @summary.reload
    seen
  end

  test "happy path walks every status and stores segments and summary" do
    seen = run_with
    assert_equal %w[downloading transcribing summarizing], seen
    assert_predicate @summary, :done?
    assert_equal SEGMENTS, @summary.segments
    assert_equal "## TL;DR\nok", @summary.summary
    assert_nil @summary.error
  end

  test "passes the downloader's chunks to the transcriber" do
    received = nil
    run_with(transcriber: ->(chunks) { received = chunks; { language: "en", segments: SEGMENTS } })
    assert_equal @download[:chunks], received
  end

  test "deletes the audio file and every chunk once transcribed" do
    run_with
    assert_not File.exist?(@audio)
    assert_not File.exist?(@chunk)
    assert_nil @summary.audio_path
  end

  test "downloader error marks failed with the message and never transcribes" do
    called = false
    run_with(downloader: ->(**) { raise Services::Error, "Downloader: private file" }, transcriber: ->(_) { called = true })
    assert_predicate @summary, :failed?
    assert_equal "Downloader: private file", @summary.error
    assert_not called
  end

  test "transient error retries then fails after the last attempt" do
    attempts = 0
    assert_enqueued_jobs 1, only: TranscribeJob do
      run_with(downloader: ->(**) { attempts += 1; raise Services::TransientError, "Downloader unreachable" })
    end
    assert_equal 1, attempts
    assert_predicate @summary.reload, :downloading? # not failed yet: a retry is scheduled

    perform_enqueued_jobs do
      run_with(downloader: ->(**) { attempts += 1; raise Services::TransientError, "Downloader unreachable" })
    end
    assert_predicate @summary.reload, :failed?
    assert_equal "Downloader unreachable", @summary.error
  end

  test "unexpected exception marks failed" do
    run_with(summarizer: ->(_) { raise "boom" })
    assert_predicate @summary, :failed?
    assert_equal "boom", @summary.error
  end

  test "already finished summaries are skipped" do
    @summary.update!(status: :done, summary: "keep")
    called = false
    run_with(downloader: ->(**) { called = true; @download })
    assert_not called
    assert_equal "keep", @summary.summary
  end
end
