#!/usr/local/bin/ruby

require 'testwebrick'
require 'webrick/httpstatus'

class TestWEBrickHTTPStatus < RUNIT::TestCase
  include WEBrick

  def setup
  end

  def test_code()
    assert_equal(200, HTTPStatus::OK.new.code)
    assert_equal(301, HTTPStatus::MovedPermanently.new.code)
    assert_equal(404, HTTPStatus::NotFound.new.code)
    assert_equal(500, HTTPStatus::InternalServerError.new.code)
  end

  def test_to_i()
    assert_equal(200, HTTPStatus::OK.new.to_i)
    assert_equal(301, HTTPStatus::MovedPermanently.new.to_i)
    assert_equal(404, HTTPStatus::NotFound.new.to_i)
    assert_equal(500, HTTPStatus::InternalServerError.new.to_i)
  end

  def test_reason_phrase
    assert_equal("OK", HTTPStatus::reason_phrase(200))
    assert_equal("Not Found", HTTPStatus::reason_phrase(404))
    assert_equal("OK", HTTPStatus::OK.new.reason_phrase)
    assert_equal("Not Found", HTTPStatus::NotFound.new.reason_phrase)
  end

  def test_info?
    assert_equal(false, HTTPStatus::info?(200))
    assert_equal(true, HTTPStatus::info?(100))
    assert_equal(true, HTTPStatus::success?(200))
    assert_equal(false, HTTPStatus::success?(100))
    assert_equal(true, HTTPStatus::error?(404))
    assert_equal(true, HTTPStatus::error?(501))
    assert_equal(true, HTTPStatus::error?(500))
    assert_equal(false, HTTPStatus::server_error?(400))
    assert_equal(true, HTTPStatus::server_error?(500))
    assert_equal(true, HTTPStatus::client_error?(400))
    assert_equal(false, HTTPStatus::client_error?(500))
  end

end

TestWEBrick::handleTests(TestWEBrickHTTPStatus) if $0 == __FILE__
