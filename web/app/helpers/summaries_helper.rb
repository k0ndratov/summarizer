module SummariesHelper
  # 65.4 → "01:05"; 3661.0 → "1:01:01"
  def format_timestamp(seconds)
    total = seconds.to_f.floor
    h, rem = total.divmod(3600)
    m, s = rem.divmod(60)
    h.positive? ? format("%d:%02d:%02d", h, m, s) : format("%02d:%02d", m, s)
  end
end
