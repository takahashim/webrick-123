#!/usr/local/bin/ruby

require 'testwebrick'
require 'webrick/log'
require 'tempfile'

class TestWEBrickLog < RUNIT::TestCase
  include WEBrick

  def setup
  end

  def test_log
    f = Tempfile.new("testlog")
    begin
      log = Log.new(f, WEBrick::Log::DEBUG)
      log.fatal("hogehoge")
      log.close
      f.rewind
      str = f.read()
      col = str.split("\n")
      i=-1
      assert_equal(" FATAL hogehoge", col[i+=1].sub(/\[.*\]/,''))
    ensure
      f.close
    end
  end


  def test_log2
    f = Tempfile.new("testlog")
    begin
      log = Log.new(f, WEBrick::Log::INFO)
      log.debug("test_debug")
      log.fatal("test_fatal")
      log.close
      f.rewind
      str = f.read()
      col = str.split("\n")
      assert_equal(" FATAL test_fatal", col[0].sub(/\[.*\]/,''))
    ensure
      f.close
    end
  end
end

TestWEBrick::handleTests(TestWEBrickLog) if $0 == __FILE__
