#!/usr/bin/env ruby

$:.unshift('../../lib')

require 'webrick'
require 'webrick/httpproxy.rb'
require 'getopts'

getopts "", 'p:8808'

class ProxyLogger
  @@mutex = Mutex.new

  def call(req, res)
    @@mutex.synchronize{
      puts "------------ Request  --------------"
      puts req.request_line
      req.each{|key, val| puts "#{key}: #{val}" }
      puts
      puts "sizeof body = #{req.body ? req.body.size : 0}"
      puts "------------ Response --------------"
      puts res.status_line
      res.each{|key, val| puts "#{key}: #{val}" }
      puts
      puts "sizeof body = #{res.body ? res.body.size : 0}"
      puts "------------------------------------"
    }
  end
end

s=WEBrick::HTTPProxyServer.new(
  :BindAddress         => "0.0.0.0",
  :Port                => $OPT_p.to_i, 
  :Logger              => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
  :ProxyContentHandler => ProxyLogger.new
)
trap("INT"){ s.shutdown }
s.start
