class TranscribeJob < ApplicationJob
  queue_as :default

  def perform(summary_id)
    # Pipeline implemented in step 4.
  end
end
