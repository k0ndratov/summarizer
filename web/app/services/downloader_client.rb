require "net/http"

# POST {DOWNLOADER_URL}/download {url, id} → path of the mp3 on the shared /data volume.
class DownloaderClient
  READ_TIMEOUT = 600 # yt-dlp on a long file can take minutes

  def initialize(base_url: ENV.fetch("DOWNLOADER_URL"))
    @base_url = URI(base_url)
  end

  def call(url:, id:)
    uri = @base_url.dup
    uri.path = "/download"
    req = Net::HTTP::Post.new(uri, "content-type" => "application/json")
    req.body = { url: url, id: id.to_s }.to_json

    res = Net::HTTP.start(uri.host, uri.port, read_timeout: READ_TIMEOUT, open_timeout: 5) { |http| http.request(req) }
    body = JSON.parse(res.body) rescue {}

    case res
    when Net::HTTPSuccess then body.fetch("path")
    when Net::HTTPServerError then raise Services::TransientError, "Downloader: #{body['error'] || res.code}"
    else raise Services::Error, "Downloader: #{body['error'] || res.code}"
    end
  rescue Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    raise Services::TransientError, "Downloader unreachable: #{e.message}"
  end
end
