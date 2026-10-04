require "test_helper"

class DownloaderClientTest < ActiveSupport::TestCase
  # Client with HTTP replaced by a scripted list of [status, body] responses.
  def client(*responses, max_wait: 600)
    requests = []
    c = DownloaderClient.new(base_url: "http://downloader:3001", poll_interval: 0, max_wait: max_wait)
    c.define_singleton_method(:request) do |req|
      requests << [ req.method, req.path, req.body && JSON.parse(req.body) ]
      status, body = responses.shift || raise("no scripted response for #{req.method} #{req.path}")
      res = Net::HTTPResponse::CODE_TO_OBJ.fetch(status.to_s).new("1.1", status.to_s, "")
      [ res, body ]
    end
    [ c, requests ]
  end

  test "starts the download, polls until done, returns path and chunks" do
    c, requests = client(
      [ 202, { "id" => "7", "status" => "running" } ],
      [ 200, { "status" => "running" } ],
      [ 200, { "status" => "done", "path" => "/data/7.mp3", "chunks" => [ { "path" => "/data/7.part000.mp3", "start" => 0 }, { "path" => "/data/7.part001.mp3", "start" => "601.5" } ] } ]
    )
    result = c.call(url: "https://drive.google.com/x", id: 7)
    assert_equal({ path: "/data/7.mp3", chunks: [ { path: "/data/7.part000.mp3", start: 0.0 }, { path: "/data/7.part001.mp3", start: 601.5 } ] }, result)
    assert_equal [ [ "POST", "/download", { "url" => "https://drive.google.com/x", "id" => "7" } ], [ "GET", "/download/7", nil ], [ "GET", "/download/7", nil ] ], requests
  end

  test "a failed download raises a permanent error with the downloader's message" do
    c, = client([ 202, {} ], [ 200, { "status" => "failed", "error" => "Unable to extract" } ])
    e = assert_raises(Services::Error) { c.call(url: "https://x", id: 1) }
    assert_equal "Downloader: Unable to extract", e.message
    assert_not_kind_of Services::TransientError, e
  end

  test "rejected start (4xx) is permanent, 5xx is transient" do
    c, = client([ 400, { "error" => "url must be an http(s) URL" } ])
    assert_equal "Downloader: url must be an http(s) URL", assert_raises(Services::Error) { c.call(url: "x", id: 1) }.message

    c, = client([ 503, {} ])
    assert_raises(Services::TransientError) { c.call(url: "https://x", id: 1) }
  end

  test "gives up as transient when the download outlives max_wait" do
    c, = client([ 202, {} ], [ 200, { "status" => "running" } ], [ 200, { "status" => "running" } ], max_wait: 0)
    assert_raises(Services::TransientError) { c.call(url: "https://x", id: 1) }
  end

  test "a lost job id is a permanent error" do
    c, = client([ 202, {} ], [ 404, { "error" => "unknown download id" } ])
    assert_match(/lost track/, assert_raises(Services::Error) { c.call(url: "https://x", id: 1) }.message)
  end
end
