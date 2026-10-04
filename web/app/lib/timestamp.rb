# Formats seconds for display and export.
module Timestamp
  # 65.4 → "01:05"; 3661.0 → "1:01:01"
  def self.clock(seconds)
    h, m, s = split(seconds)
    h.positive? ? format("%d:%02d:%02d", h, m, s) : format("%02d:%02d", m, s)
  end

  # 65.4 → "00:01:05,400" (SubRip)
  def self.srt(seconds)
    h, m, s = split(seconds)
    ms = ((seconds.to_f - seconds.to_f.floor) * 1000).round
    format("%02d:%02d:%02d,%03d", h, m, s, ms)
  end

  def self.split(seconds)
    total = seconds.to_f.floor
    h, rem = total.divmod(3600)
    [ h, *rem.divmod(60) ]
  end
  private_class_method :split
end
