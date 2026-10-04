require "test_helper"

class SummariesControllerTest < ActionDispatch::IntegrationTest
  test "create enqueues the job and redirects to the summary" do
    assert_enqueued_with(job: TranscribeJob) do
      assert_difference("Summary.count", 1) do
        post summaries_url, params: { summary: { source_url: "https://drive.google.com/file/d/abc/view" } }
      end
    end
    summary = Summary.last
    assert_redirected_to summary_url(summary)
    assert_enqueued_with(job: TranscribeJob, args: [ summary.id ])

    follow_redirect!
    assert_select "[data-status]", "pending"
  end

  test "create with invalid URL re-renders the form with an error" do
    assert_no_enqueued_jobs do
      assert_no_difference("Summary.count") do
        post summaries_url, params: { summary: { source_url: "not a url" } }
      end
    end
    assert_response :unprocessable_entity
    assert_select ".error"
  end

  test "show renders status" do
    summary = Summary.create!(source_url: "https://x.test/v", status: :failed, error: "boom")
    get summary_url(summary)
    assert_response :success
    assert_select "[data-status]", "failed"
    assert_select ".error", "boom"
  end
end
