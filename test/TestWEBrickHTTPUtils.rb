#!/usr/local/bin/ruby

require 'testwebrick'
require 'webrick/httputils'
require 'tempfile'

class TestWEBrickHTTPUtils < RUNIT::TestCase
  include WEBrick::HTTPUtils

  def setup
  end

  def test_normilize_path
    assert_equal("/foo",       normalize_path("/foo"))
    assert_equal("/foo/bar/",  normalize_path("/foo/bar/"))

    assert_equal("/",          normalize_path("/foo/../"))
    assert_equal("/",          normalize_path("/foo/.."))
    assert_equal("/",          normalize_path("/foo/bar/../../"))
    assert_equal("/",          normalize_path("/foo/bar/../.."))
    assert_equal("/",          normalize_path("/foo/bar/../.."))
    assert_equal("/baz",       normalize_path("/foo/bar/../../baz"))
    assert_equal("/baz",       normalize_path("/foo/../bar/../baz"))
    assert_equal("/baz/",      normalize_path("/foo/../bar/../baz/"))
    assert_equal("/...",       normalize_path("/bar/../..."))
    assert_equal("/.../",      normalize_path("/bar/../.../"))

    assert_equal("/foo/",      normalize_path("/foo/./"))
    assert_equal("/foo/",      normalize_path("/foo/."))
    assert_equal("/foo/",      normalize_path("/foo/././"))
    assert_equal("/foo/",      normalize_path("/foo/./."))
    assert_equal("/foo/bar",   normalize_path("/foo/./bar"))
    assert_equal("/foo/bar/",  normalize_path("/foo/./bar/."))
    assert_equal("/foo/bar/",  normalize_path("/./././foo/./bar/."))

    assert_equal("/foo/bar/",  normalize_path("//foo///.//bar/.///.//"))
    assert_equal("/",          normalize_path("//foo///..///bar/.///..//.//"))

    assert_exception(RuntimeError){ normalize_path("foo/bar") }
    assert_exception(RuntimeError){ normalize_path("..") }
    assert_exception(RuntimeError){ normalize_path("/..") }
    assert_exception(RuntimeError){ normalize_path("/./..") }
    assert_exception(RuntimeError){ normalize_path("/./../") }
    assert_exception(RuntimeError){ normalize_path("/./../..") }
    assert_exception(RuntimeError){ normalize_path("/./../../") }
    assert_exception(RuntimeError){ normalize_path("/./../") }
    assert_exception(RuntimeError){ normalize_path("/../..") }
    assert_exception(RuntimeError){ normalize_path("/../../") }
    assert_exception(RuntimeError){ normalize_path("/../../..") }
    assert_exception(RuntimeError){ normalize_path("/../../../") }
    assert_exception(RuntimeError){ normalize_path("/../foo/../") }
    assert_exception(RuntimeError){ normalize_path("/../foo/../../") }
    assert_exception(RuntimeError){ normalize_path("/foo/bar/../../../../") }
    assert_exception(RuntimeError){ normalize_path("/foo/../bar/../../") }
    assert_exception(RuntimeError){ normalize_path("/./../bar/") }
    assert_exception(RuntimeError){ normalize_path("/./../") }
  end

  def test_escape
    assert_equal("/foo/bar", escape("/foo/bar"))
    assert_equal("/~foo/bar", escape("/~foo/bar"))
    assert_equal("/~foo bar", escape("/~foo bar"))
    assert_equal("/~foo bar", escape("/~foo bar"))
    assert_equal("/~foo%09bar", escape("/~foo\tbar"))
    assert_equal("/~foo+bar", escape("/~foo+bar"))
  end

  def test_escape_form
    assert_equal("%2Ffoo%2Fbar", escape_form("/foo/bar"))
    assert_equal("%2F~foo%2Fbar", escape_form("/~foo/bar"))
    assert_equal("%2F~foo+bar", escape_form("/~foo bar"))
    assert_equal("%2F~foo+%2B+bar", escape_form("/~foo + bar"))
  end

  def test_unescape
    assert_equal("/foo/bar", unescape("%2ffoo%2fbar"))
    assert_equal("/~foo/bar", unescape("/%7efoo/bar"))
    assert_equal("/~foo/bar", unescape("%2f%7efoo%2fbar"))
    assert_equal("/~foo+bar", unescape("/%7efoo+bar"))
  end

  def test_unescape_form
    assert_equal("//foo/bar", unescape_form("/%2Ffoo/bar"))
    assert_equal("//foo/bar baz", unescape_form("/%2Ffoo/bar+baz"))
    assert_equal("/~foo/bar baz", unescape_form("/%7Efoo/bar+baz"))
  end
end

TestWEBrick::handleTests(TestWEBrickHTTPUtils) if $0 == __FILE__
