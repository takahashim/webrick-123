#!/usr/local/bin/ruby

require 'testwebrick'
require 'ftools'
require 'webrick/httpserver'

class TestWEBrickHTTPServer < RUNIT::TestCase
  include WEBrick

  def setup
    logger = Log.new(nil, Log::FATAL)
    @svr = HTTPServer.new(:Logger=>logger, :DoNotListen => true)
  end

  def teardown
  end

  def test_search_servlet
    result = @svr.search_servlet("")
    assert_equals(nil, result)

    result = @svr.search_servlet("/hoge")
    assert_equals(nil, result)

    @svr.mount("/", :Root, 1, 2, 3)
    @svr.mount("/foo", :Foo, 2, 3, 4)
    @svr.mount("/foo/bar", :Bar)
    @svr.mount("/foo/bar/baz", :Baz)

    result = @svr.search_servlet("/")
    assert_equals([:Root, [1,2,3], "", "/"], result)

    result = @svr.search_servlet("/foo")
    assert_equals([:Foo, [2,3,4], "/foo", ""], result)

    result = @svr.search_servlet("/fooo")
    assert_equals([:Root, [1,2,3], "", "/fooo"], result)

    result = @svr.search_servlet("/foo/bar/")
    assert_equals([:Bar, [], "/foo/bar", "/"], result)

    result = @svr.search_servlet("/foo/bar/hoge")
    assert_equals([:Bar, [], "/foo/bar", "/hoge"], result)

    result = @svr.search_servlet("/foo/bar/baz")
    assert_equals([:Baz, [], "/foo/bar/baz", ""], result)

    result = @svr.search_servlet("/foo/bar/baz/qux")
    assert_equals([:Baz, [], "/foo/bar/baz", "/qux"], result)

    result = @svr.unmount("/")

    result = @svr.search_servlet("/")
    assert_equals(nil, result)

    result = @svr.search_servlet("/foo")
    assert_equals([:Foo, [2,3,4], "/foo", ""], result)

    result = @svr.search_servlet("/hoge")
    assert_equals(nil, result)

    @svr.mount("/-", :Hyph, 3, 4, 5) 
    result = @svr.search_servlet("/--")
    assert_equals(nil, result)
  end

end

TestWEBrick::handleTests(TestWEBrickHTTPServer) if $0 == __FILE__
