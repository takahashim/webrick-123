#
# rfc.rb -- RFC browsing utility.
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (C) 2002 TAKAHASHI Masayoshi, GOTOU YUUZOU
#
# $IPR: rfc.rb,v 1.19 2002/05/28 07:39:42 gotoyuzo Exp $

require 'webrick'
require 'thread'
require 'net/ftp'
require 'net/http'
require 'erb/erbl'

class RFCExplorer < WEBrick::HTTPServlet::AbstractServlet

  TopPage = <<-_end_of_html_
<HTML>
  <HEAD>
    <TITLE>RFC Explorer Top Page</TITLE>
  <HEAD>

  <%
     up = Hash.new("unavailable")
     [ "rfc", "std", "bcp", "fyi" ].each{|i|
       path = File::join(@rfc_cache_dir, i+"-index.txt")
       begin
         open(path){|io|
           io.each{|line|
             if %r/CREATED ON: (.*)\\./o =~ line
               up[i] = $1
               break
             end
           }
         }
       rescue Errno::ENOENT
       rescue
         logger.backtrace($!)
       end
     }
  %>

  <BODY>
    <H2>View specific RFC by number</H2>
    <FORM method="GET" action="view_rfc">
      RFC<INPUT type="text" name="number" size="4">.txt
    </FORM>
    <HR>
    <H2>Search the RFC index</H2>
    <FORM method="GET" action="search_index">
      Search {rfc,std,bcp,fyi}-index.txt by regular expression:<BR>
      <INPUT type="text" name="patterns"> and
      <INPUT type="text" name="patterns"> and
      <INPUT type="text" name="patterns"><BR>
      from: <SELECT name="search_from">
        <OPTION selected>rfc-index
        <OPTION>std-index
        <OPTION>bcp-index
        <OPTION>fyi-index
      </SELECT>
      <INPUT type="submit">
    </FORM>
    <HR>
    <H2>View hyperlinked index of RFCs</H2>
      <UL>
        <LI><A href="rfc-index.html">All RFCs</A> (<%=up["rfc"]%>)
        <LI><A href="std-index.html">Internet Standard</A> (<%=up["std"]%>)
        <LI><A href="bcp-index.html">Best Current Practice</A> (<%=up["bcp"]%>)
        <LI><A href="fyi-index.html">For Your Interest</A> (<%=up["fyi"]%>)
      </UL>
      <FORM action="update_index">
        Update all index: <INPUT type="submit" name="all" value="go">
      </FROM>
    <HR>
    <H2>RFC related sites</H2>
      <UL>
        <LI><A href="http://www.rfc-editor.org/">
          Request for Comments Editor Homepage</A>
        <LI><A href="http://www.ietf.org/1id-abstracts.html">
          Current Internet-Drafts</A>
        <LI><A href="http://www.isoc.org/">ISOC - The Internet Society</A>
        <LI><A href="http://www.iab.org/">
          IAB - The Internet Architecture Board </A>
        <LI><A href="http://www.ietf.org/">
          IETF - The Internet Engineering Task Force</A>
        <LI><A href="http://www.ietf.org/iesg.html">
          IESG - The Internet Enginnering Steering Group</A>
        <LI><A href="http://www.irtf.org/">
          IRTF - The Internet Research Task Force</A>
        <LI><A>
          IRSG - The Internet Research Steering Group</A>
        <LI><A href="http://www.icann.org/">
          ICANN - The Internet Corporation for Assigned Names and Numbers</A>
        <LI><A href="http://www.iana.org/">
          IANA - The Internet Assigned Numbers Authority</A>
      </UL>
    <HR>
    <ADDRESS>
      <%= @config[:ServerSoftware] %><BR>
      <%= "$IPR: rfc.rb,v 1.19 2002/05/28 07:39:42 gotoyuzo Exp $" %>
    </ADDRESS>
  </BODY>
</HTML>
  _end_of_html_

  #################################################################

  GetRFCMutex = Mutex.new
  GetIndexMutex = Mutex.new
  CreateIndexMutex = Mutex.new

  def initialize(config, option={})
    super
    @rfc_cache_dir = option[:RFCCacheDir]
    @rfc_site_url = option[:RFCSiteURL]
  end

  def config; @config; end
  def logger; @config[:Logger]; end

  #################################################################

  def do_GET(req, res)
    # /                         => returns TopPage
    # /*.txt                    => returns *.txt
    # /xxx-index.html           => returns a HTML converted from xxx-index.txt
    # /view_rfc?num=N           => redurects to /rfcN.txt
    # /search_index?patterns=RE => searchs rfc-index.txt by RE
    # /update_index             => updates *-index.txt

    logger.debug "#{type}#do_GET: #{req.request_uri}" 
    case req.path_info
    when "/"
      create_top_page(req, res)
    when /^\/([\w-]+)\.txt$/o
      create_rfc_page(req, res, $1)
    when /^\/((?:bcp|fyi|rfc|std)-index)\.html$/o
      create_index_html(req, res, $1)
    when "/view_rfc"
      view_rfc(req, res)
    when "/search_index"
      search_index(req, res)
    when /^\/update_index$/o
      update_index(req, res)
    else
      redirect_to_directory_uri(req, res)
      raise WEBrick::HTTPStatus::NotFound, "`#{req.request_uri}' not found."
    end
  end

  #################################################################

  def create_top_page(req, res)
    res.body = ERbLight.new(TopPage).result(binding)
    res['content-type'] = "text/html"
  end

  #################################################################

  def view_rfc(req, res)
    if num = req.query['number']
      logger.debug "#{type}#view_rfc: number=#{num}"
      num = num.to_i.to_s if /^\d+$/ =~ num  # 0001 ==> 1
      res.set_redirect(WEBrick::HTTPStatus::Found, "rfc#{num}.txt")
    end
  end

  #################################################################

  def search_index(req, res)
    unless patterns = req.query["patterns"]
      res.body = "<HTML><HEAD><TITLE>Result:</TITLE></HEAD><BODY>\n"
      res.body << "<H1>Search result</H1><HR>\n"
      res.body << "No pattern is specified.\n"
      res.body << "</BODY></HTML>\n"
      res['content-type'] = "text/html"
      raise WEBrick::HTTPStatus::OK
    end

    dir = @rfc_cache_dir
    name = req.query['search_from']    # one of {rfc,std,bcp,fyi}-index
    filename = name + ".txt"

    path = File.join(dir, filename)
    GetIndexMutex.synchronize{
      if not File.exist?(path)
        dir = @rfc_cache_dir
        site = @rfc_site_url
        get_rfc(site, dir, filename)
      end
    }

    logger.debug "#{type}#search_index: #{name}, #{patterns.inspect}"
    data = open(path){|io| io.read }
    patterns.split(/\0/).each{|pat|
      next if pat.empty?
      regex = Regexp.new(pat, "i")
      result = []
      data.scan(/^\d+.*?\n(?:\n|\z)/im){|text|
        if regex =~ text.gsub(/\s+/, ' ')
          result << text
        end
      }
      data = result.join
    }

    res.body = "<HTML><HEAD><TITLE>Result:</TITLE></HEAD><BODY>\n"
    res.body << "<H1>Search result</H1><HR><PRE>\n"
    search_res = markup_index(data, name)
    if search_res.empty?
      res.body << "NO MATCHES WARE FOUND.\n"
    else
      res.body << search_res
    end
    res.body << "</PRE><HR>\n"
    res.body << "</BODY></HTML>\n"
    res['content-type'] = "text/html"
  end

  #################################################################

  def create_index_html(req, res, name)
    dir = @rfc_cache_dir
    txt = File.join(dir, name + ".txt")
    html = File.join(dir, name + ".html")

    GetIndexMutex.synchronize{
      if not File.exist?(txt)
        dir = @rfc_cache_dir
        site = @rfc_site_url
        get_rfc(site, dir, name+".txt")
      end
    }

    # If the HTML file is older than the plain text file,
    # The HTML file will be rebuilded from the text file.
    CreateIndexMutex.synchronize{
      if not File.exist?(html) or File.mtime(html) < File.mtime(txt)
        data = open(txt){|io| io.read }
        open(html, "w"){|io|
          io.print "<HTML><HEAD><TITLE>#{name}</TITLE></HEAD><BODY><PRE>\n"
          io.print markup_index(data, name)
          io.print "</PRE></BODY></HTML>\n"
        }
      end
    }

    # raed the HTML file.
    res.body = open(html){|io| io.read }
    res['content-type'] = 'text/html'
  end

  #################################################################

  def create_rfc_page(req, res, name)
    dir = @rfc_cache_dir
    filename = name + ".txt"
    pathname = File.join(dir, filename)

    GetRFCMutex.synchronize{
      if not File.exist?(pathname)
        unless req.query['get']
          # confirm before getting.
          res.body =  "<HTML><HEAD><TITLE>Confirmation</TITLE></HEAD>"
          res.body << "<BODY>\n"
          res.body << "There is no `#{filename}' at local. "
          res.body << "Do you want to fetch it?<BR>"
          res.body << "[<A href=\"#{filename}?get=yes\">Yes</A>]/"
          res.body << "[<A href=\".\">No</A>]\n"
          res.body << "</BODY></HTML>\n"
          res['content-type'] = "text/html"
          raise WEBrick::HTTPStatus::OK    # break
        else
          site = @rfc_site_url
          dir = @rfc_cache_dir
          get_rfc(site, dir, filename)
        end
      end
    }
    res['content-type'] = "text/plain"
    res.body = open(pathname){|io| io.read }
  end

  #################################################################

  def update_index(req, res)
    files = [ "rfc", "std", "bcp", "fyi" ].collect{|i| i + "-index.txt" }
    dir = @rfc_cache_dir
    site = @rfc_site_url
    GetIndexMutex.synchronize{ get_rfc(site, dir, *files) }
    res.set_redirect(WEBrick::HTTPStatus::Found, "#{req.script_name}/")
  end

  #################################################################

  def get_rfc(url, dir, *names)
    logger.debug "#{type}#get_rfc: #{url} #{dir} #{names.inspect}"
    raise WEBrick::HTTPStatus::InternalServerError,
      "Server configuration not satisfied. :RFCSiteURL" unless url
    uri = URI.parse(url)
    case uri.scheme
    when "ftp"
      logger.debug "#{type}#get_rfc: FTP.new(#{uri.host})"
      ftp = Net::FTP.new(uri.host)
      begin
        ftp.passive
        ftp.login
        ftp.chdir(uri.path)

        names.each{|name|
          localfile = File.join(dir, name)
          if sz = File.size?(localfile)
            if sz == ftp.size(name)
              logger.debug "#{type}#get_rfc: skip #{name}"
              next
            end
          end
          logger.debug "#{type}#get_rfc: FTP#gettextfile(#{name})"
          ftp.gettextfile(name, localfile)
        }
      ensure
        ftp.close
      end
    when "http"
      logger.debug "#{type}#get_rfc: HTTP.start(#{uri.host},#{uri.port})"
      Net::HTTP.start(uri.host, uri.port){|http|
        names.each{|name|
          path = uri.path
          path << "/" if path[-1] != ?/
          localfile = File.join(dir, name)

          if sz = File.size?(localfile)
            resp = http.head2("#{path}#{name}")
            if sz == resp['content-length'].to_i
              logger.debug "#{type}#get_rfc: skip #{name}"
              next
            end
          end

          logger.debug "#{type}#get_rfc: HTTP#get2(#{path}#{name})"
          http.get2("#{path}#{name}"){|resp|
            unless resp.code.to_i == 200
              raise WEBrick::HTTPStatus::InternalServerError,
                    "Cannot get `#{name}': #{resp.message}"
            end
            open(localfile, "w"){|io| io.write resp.body }
          }
        }
      }
    else
      raise WEBrick::HTTPStatus::InternalServerError,
            "unsupported scheme: `#{url}'"
    end
  end

  def markup_index(data, name)
    data.gsub(/^\d+.*?\n(?:\n|\z)/om){ |text|
      text.gsub!(/RFC\d+/o){ |ref|
        "<A href='rfc-index.html\##{ref}'>#{ref}</A>"
      }
      if /rfc-index/ =~ name
        text.sub!(/^\d+/o){ |num|
          "<A name='RFC#{num}' href='rfc#{num.to_i.to_s}.txt'>" +
          num + "</A>"
        }
      end
      text
    }
  end

end

def _setup_rfc(svr, mount_point)
  svr.mount(mount_point, RFCExplorer, {
     #:RFCSiteURL  => "ftp://ftp.isi.edu/in-notes/",
      :RFCSiteURL  => "http://ring.gr.jp/archives/doc/RFC/",
      :RFCCacheDir => File::join(DocumentRoot, "rfc")
    }
  )
  svr.logger.info "RFCExplorer: mounted on `#{mount_point}'."
end
