#!/usr/local/bin/ruby

require 'testwebrick'
require 'webrick/httprequest'
require 'webrick/config'
require 'webrick/uri'

require 'tempfile'

class TestWEBrickHTTPRequest < RUNIT::TestCase
  include WEBrick

  def setup
    @io = Tempfile.new("testhttprequest")
    @req = HTTPRequest.new(Config::HTTP)
  end

  def teardown
    @io.close
  end

  def test_s_new()
    assert_instance_of(WEBrick::HTTPRequest, @req)
  end

  def test_parse()
    @io.puts <<-"EOB"
POST / HTTP/1.0\r
Host: exapmle.jp\r
Content-Length: 9\r
User-Agent: \r
	FOO \t  BAR\r
	\r
	BAZ\r
\r
hogehoge
    EOB
    @io.rewind
    @req.parse(@io)
    assert_equal(1, @req.http_version.major)
    assert_equal(0, @req.http_version.minor)
    assert_equal("POST / HTTP/1.0\r\n", @req.request_line)
    assert_equal("POST", @req.request_method)
    assert_equal("/", @req.request_uri.path)
    assert_equal("9", @req['content-length'])
    assert_equal("FOO BAR BAZ", @req['user-agent'])
    assert_equal("hogehoge\n", @req.body)
    assert_equal(false, @req.keep_alive?)
  end

  def test_parse_lf()
    @io.puts <<-"EOB"
POST /foo/bar/../baz?q=a HTTP/1.0
Host: example.jp:8080
Content-Length: 9
User-Agent: 
	FOO   BAR
	
	BAZ

hogehoge
    EOB
    @io.rewind
    @req.parse(@io)
    assert_equal(1, @req.http_version.major)
    assert_equal(0, @req.http_version.minor)
    assert_equal("POST /foo/bar/../baz?q=a HTTP/1.0\n", @req.request_line)
    assert_equal("POST", @req.request_method)
    assert_equal("/foo/bar/../baz", @req.request_uri.path)
    assert_equal("/foo/baz", @req.path)
    assert_equal("", @req.script_name)
    assert_equal("/foo/baz", @req.path_info)
    assert_equal("9", @req['content-length'])
    assert_equal("FOO BAR BAZ", @req['user-agent'])
    assert_equal("hogehoge\n", @req.body)
    assert_equal(false, @req.keep_alive?)
    assert_equal("http://example.jp:8080/foo/bar/../baz?q=a",
                 @req.request_uri.to_s)
  end

end

TestWEBrick::handleTests(TestWEBrickHTTPRequest) if $0 == __FILE__
