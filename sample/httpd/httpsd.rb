#!/usr/bin/env ruby

$:.unshift('../../lib')

require 'webrick/https'
require 'getopts'

getopts nil, 'r:', 'p:8808'

dir = File::dirname(File::expand_path(__FILE__))

pkey = cert = cert_name = nil
begin
  data = open(dir + "/conf/sample.key"){|io| io.read }
  pkey = OpenSSL::PKey::RSA.new(data)
  data = open(dir + "/conf/sample.crt"){|io| io.read }
  cert = OpenSSL::X509::Certificate.new(data)
rescue
  $stderr.puts "Switching to use self-signed certificate"
  cert_name = [ ["C","JP"], ["O","Example.JP"], ["CN", "WWW"] ]
end

s=WEBrick::HTTPServer.new(
  :BindAddress      => "0.0.0.0",
  :Port             => $OPT_p.to_i, 
  :Logger           => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG),
  :DocumentRoot     => $OPT_r || dir + "/htdocs",
  :SSLEnable        => true,
  :SSLVerifyClient  => ::OpenSSL::SSL::VERIFY_NONE,
  :SSLCertificate   => cert,
  :SSLPrivateKey    => pkey,
  :SSLCertName      => cert_name
)
trap("INT"){ s.shutdown }
s.start
