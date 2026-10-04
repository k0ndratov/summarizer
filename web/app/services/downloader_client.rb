require "net/http"

# Starts a download on the downloader service and polls until it finishes.
# Returns { path:, chunks: [{ path:, start: }, ...] } — chunks are pieces small
# enough for Whisper, `start` is each piece's offset in seconds.
class DownloaderClient
  POLL_INTERVAL = 2   # seconds between status checks
  MAX_WAIT = 600      # give up on a single download after this long

  def initialize(base_url: ENV.fetch("DOWNLOADER_URL"), poll_interval: POLL_INTERVAL, max_wait: MAX_WAIT)
    @base_url = URI(base_url)
    @poll_interval = poll_interval
    @max_wait = max_wait
  end

  def call(url:, id:)
    start(url, id.to_s)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @max_wait
    loop do
      job = status(id.to_s)
      case job["status"]
      when "done" then return { path: job.fetch("path"), chunks: job.fetch("chunks").map { |c| { path: c["path"], start: c["start"].to_f } } }
      when "failed" then raise Services::Error, "Downloader: #{job['error']}"
      end
      raise Services::TransientError, "Downloader: no result after #{@max_wait}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep @poll_interval
    end
  end

  private

  def start(url, id)
    req = Net::HTTP::Post.new(path("/download"), "content-type" => "application/json")
    req.body = { url: url, id: id }.to_json
    res, body = request(req)
    return if res.is_a?(Net::HTTPAccepted)
    raise Services::TransientError, "Downloader: #{body['error'] || res.code}" if res.is_a?(Net::HTTPServerError)
    raise Services::Error, "Downloader: #{body['error'] || res.code}"
  end

  def status(id)
    res, body = request(Net::HTTP::Get.new(path("/download/#{id}")))
    return body if res.is_a?(Net::HTTPSuccess)
    raise Services::Error, "Downloader: lost track of download #{id} (#{res.code})"
  end

  def path(suffix) = @base_url.dup.tap { |u| u.path = suffix }

  def request(req)
    res = Net::HTTP.start(@base_url.host, @base_url.port, open_timeout: 5, read_timeout: 15) { |http| http.request(req) }
    [ res, (JSON.parse(res.body) rescue {}) ]
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    raise Services::TransientError, "Downloader unreachable: #{e.message}"
  end
end
