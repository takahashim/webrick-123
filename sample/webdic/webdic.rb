#! /usr/local/bin/ruby -Ke

require 'ndtp'
require 'webrick'
require 'getopts'

getopts "", 'p:8808'

class WebDic < WEBrick::HTTPServlet::AbstractServlet
  def initialize(config, ndtp)
    @config = config
    @ndtp = ndtp
  end

  def do_GET(req, res)
    body = "<HTML>"
    body << "<FORM method='GET' action='#{req.script_name}/'>" +
            "word: <INPUT name='word'>" +
            "<INPUT type='hidden' name='cmd' value='scan'>" +
            "</FORM><HR>"
    case req.query['cmd']
    when 'scan'
      body << scan(req.query['word'])
    when 'consult'
      body << consult(req.query['dic'], req.query['pos'])
    end
    body << "</HTML>"
    res.body = body

    res['content-type'] = 'text/html'
  end

  def consult(dic, pos)
    return unless dic
    return unless pos
    result = @ndtp.consult(dic, pos)

    ret = ""
    while i = result.index(Ndtp::REFERENCE_REGEX)
      i -= 1
      len = $&.length
      href = WEBrick::HTMLUtils::escape("?cmd=consult&dic=#{dic}&pos=#{$1}")
      ret << WEBrick::HTMLUtils::escape(result[0..i])
      ret << "(<a href='#{href}'><i>see</i></a>)"
      result[0..(i+len)] = ""
    end
    ret << WEBrick::HTMLUtils::escape(result)

    set_gaiji(ret)
    ret.gsub!(/\n/, "<BR>")
    ret.sub!(/^/, "<P>")
    ret.sub!(/\Z/, "</P>")
    ret
  end
  
  def scan(word)
    return unless word
    result = ''
    @ndtp.dic_list.each{|i, dic, name|
      result << "<H2>¡ü " << name << "</H2>"
      result << "<UL>"
      @ndtp.entry(dic, word).each{|index, pos|
         set_gaiji(index)
         href = "?cmd=consult&dic=#{dic}&pos=#{pos}"
         href = WEBrick::HTMLUtils::escape(href)
         result << "<LI>" << "<A href='#{href}'>"
         result << WEBrick::HTMLUtils::escape(index) << "</A>"
      }
      result << "</UL>"
    }
    result
  end

  def set_gaiji(str)
    str.gsub!(Ndtp::GAIJI_REGEX, "")      # dummy
  end
end

if __FILE__ == $0
  s = WEBrick::HTTPServer.new(
    :Port         => $OPT_p.to_i,
    :StartThreads => 1,
    :Logger       => WEBrick::Log::new($stderr, WEBrick::Log::DEBUG)
  )
  s.mount("/", WebDic, Ndtp.new(:Debug=>$DEBUG))
  trap("INT"){ s.shutdown }
  s.start
end
