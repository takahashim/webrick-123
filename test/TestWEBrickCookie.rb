#!/usr/local/bin/ruby

require 'testwebrick'
require 'webrick/cookie'

class TestWEBrickCookie < RUNIT::TestCase
  include WEBrick

  def setup
    @cookie = Cookie.new("foo","bar")
  end

  def test_s_new()
    assert_equal("foo", @cookie.name)
    assert_equal("bar", @cookie.value)
  end

  def test_to_s()
    assert_equal("foo=bar", @cookie.to_s)
  end

  def test_max_age()
    t = 1000000000
    @cookie.max_age = t
    assert_match(t.to_s, @cookie.to_s)
  end

  def test_expires()
    t = Time.at(1000000000)
    @cookie.expires = t
    assert_equal(Time, @cookie.expires.type)
    assert_equal(t, @cookie.expires)

    ts = t.httpdate
    @cookie.expires = ts
    assert_equal(Time, @cookie.expires.type)
    assert_equal(t, @cookie.expires)
    assert_match(ts, @cookie.to_s)
  end

  def test_parse()
    data = ""
    data << '$Version="1"; '
    data << 'Customer="WILE_E_COYOTE"; $Path="/acme"; '
    data << 'Part_Number="Rocket_Launcher_0001"; $Path="/acme"; '
    data << 'Shipping="FedEx"; $Path="/acme"'
    cookies = Cookie.parse(data)
    assert_equal(1, cookies[0].version)
    assert_equal("Customer", cookies[0].name)
    assert_equal("WILE_E_COYOTE", cookies[0].value)
    assert_equal("/acme", cookies[0].path)
    assert_equal(1, cookies[1].version)
    assert_equal("Part_Number", cookies[1].name)
    assert_equal("Rocket_Launcher_0001", cookies[1].value)
    assert_equal(1, cookies[2].version)
    assert_equal("Shipping", cookies[2].name)
    assert_equal("FedEx", cookies[2].value)

    data = "hoge=moge; __div__session=9865ecfd514be7f7"
    cookies = Cookie.parse(data)
    assert_equal(0, cookies[0].version)
    assert_equal("hoge", cookies[0].name)
    assert_equal("moge", cookies[0].value)
    assert_equal("__div__session", cookies[1].name)
    assert_equal("9865ecfd514be7f7", cookies[1].value)
  end
end

TestWEBrick::handleTests(TestWEBrickCookie) if $0 == __FILE__
