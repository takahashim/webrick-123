#!/usr/bin/env ruby

$:.unshift('../../lib')

require 'webrick'
require 'getopts'

getopts "", 'r:', 'p:8808'

dir = File::dirname(File::expand_path(__FILE__))

s=WEBrick::HTTPServer.new(
  :BindAddress    => "0.0.0.0",
  :Port           => $OPT_p.to_i, 
  :Logger         => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
  :DocumentRoot   => $OPT_r || dir + "/htdocs",
  :CGIPathEnv     => ENV['PATH']  # Especially for Cygwin
)
trap("INT"){ s.shutdown }
s.start
