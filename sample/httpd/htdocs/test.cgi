#!/usr/bin/env ruby

require "cgi"

class SampleCGI < CGI
  def create_form(method)
    form("METHOD"=>method, "ACTION"=>ENV["SCRIPT_NAME"]){
      text_field("text") + br +
      " 1:" + radio_button("radio", "1", true) +
      " 2:" + radio_button("radio", "2") +
      " 3:" + radio_button("radio", "3") +
      br +
      submit
    }
  end

  def dump_data(hash)
    pre{
      data = ""
      hash.sort.each{|key, val|
        data << "#{CGI.escapeHTML key}: #{CGI.escapeHTML val.inspect}\n"
      }
      data
    }
  end

  def main
    out{
      h1{ "Sample"         } +
      h2{ "Testing GET"    } + create_form("GET") +
      h2{ "Testing POST"   } + create_form("POST") +
      h2{ "Meta Variables" } + dump_data(ENV) +
      h2{ "Form Data"      } + dump_data(params) +
      h2{ "Ruby Version"   } +
       "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
    }
  end
end

SampleCGI.new("html4").main
