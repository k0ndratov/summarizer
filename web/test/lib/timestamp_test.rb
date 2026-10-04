require "test_helper"

class TimestampTest < ActiveSupport::TestCase
  test "clock" do
    assert_equal "00:00", Timestamp.clock(0)
    assert_equal "00:59", Timestamp.clock(59.999)
    assert_equal "01:00", Timestamp.clock(60)
    assert_equal "1:00:00", Timestamp.clock(3600)
    assert_equal "1:01:01", Timestamp.clock(3661.4)
  end

  test "srt" do
    assert_equal "00:00:00,000", Timestamp.srt(0)
    assert_equal "00:00:59,999", Timestamp.srt(59.999)
    assert_equal "00:01:05,400", Timestamp.srt(65.4)
    assert_equal "01:01:01,250", Timestamp.srt(3661.25)
  end
end
