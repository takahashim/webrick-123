#! /usr/local/bin/ruby
#
# ndtp.rb -- Network Dictionary Transfer Protocol (NDTP) client
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (C) 2000-2002 WATANABE Tetsuya, GOTOU YUUZOU
#
# $IPR: ndtp.rb,v 1.2 2002/01/28 16:31:19 gotoyuzo Exp $

require 'socket'
require 'thread'
require 'nkf'

class Ndtp
  GAIJI_REGEX = /\#[0-9a-z]{4}/
  REFERENCE_REGEX = /<([\da-f]+?:[\da-f]+?)>/

  class NdtpError < StandardError; end

  attr_reader :dic_list, :debug

  def close
    send("Q")
    @ds.close
  end

  def entry(no, word)
    word = NKF.nkf('-emZ', word)
    ret = []
    dup_chk = {}
    @mutex.synchronize{
      select_dic(no)
      cmdlist = (@ndtp_type == 'ndtpd') ? ['a'] : ['k', 'a']
      for command in cmdlist
        command.upcase! if /^\*/ =~ word
        send('P', command, word)
        count = 0
        index = nil

        while result = recv()
	  result.chomp!
	  break if /^\$\$/ =~ result
	  next if /^\$0/ =~ result
          if /^\$\?/ =~ result
            raise NdtpError, "bad argument: #{word}"
          end

	  if count % 2 == 0
	    index = result
	  elsif not dup_chk.key?(result)
            ret << [ index, result ]
	    dup_chk[result] = true
	  end
	  count += 1
        end
      end
    }
    ret
  end

  def consult(no, pos)
    ret = ''
    @mutex.synchronize{
      select_dic(no)
      send('S', pos)
      while result = recv()
        break if /^\$\$/ =~ result
        next if /^\$1/ =~ result
        ret.concat(result)
      end
    }
    ret
  end

  private

  def initialize(config={})
    host = config[:Host] || "localhost"
    port = config[:Port] || "ndtp"
    unless user = config[:User]
      user = ENV['USER'] || ENV['LOGNAME'] || 'noname'
      user << "@" << %x(hostname)
    end

    @ds = TCPSocket.open(host, port)
    @ds.sync = true
    @mutex = Mutex.new
    @debug = config[:Debug]

    chk_ndtp_type()
    user_auth(user)
    @dic_list = get_dic_list()
  end

  def send(*args)
    str = args.join + "\n"
    $stderr.puts "Ndtp send: #{str}" if @debug
    @ds.print(str)
  end

  def recv()
    str = @ds.gets
    $stderr.puts "Ndtp recv: #{str}" if @debug
    str
  end

  def chk_ndtp_type()
    send('v')
    result = recv()
    @ndtp_type = /ndtpd/ =~ result ? "ndtpd" : "dserver"
  end

  def user_auth(name)
    send('A', name)
    while result = recv()
      case result
      when /^\$A/
	return
      when /^\$N/
        raise NdtpError, 'authentication failure'
      else
        raise NdtpError, 'ndtp protocol error'
      end
    end
  end

  def get_dic_list
    ret = []
    send("t")
    while result = recv()
      break if /^\$\*/ =~ result
      no, dicname, name = result.split
      ret << [ no.to_i, name, dicname ]
    end
    ret
  end

  def select_dic(no)
    if no.is_a?(String)
      if dic = @dic_list.rassoc(no)
        no = dic[0]
      else
        no = no.to_i
      end
    end
    send("L#{no}")
    unless recv() =~ /\$\*/
      raise NdtpError, "cannot select dictionary"
    end
  end
end

if __FILE__ == $0
  require 'readline'
  NDTPSERVER = ENV['NDTPSERVER'] || "localhost"
  PAGER      = ENV['PAGER'] || "more"
  $KCODE     = 'EUC'

  def pipe_open(cmd)
    rd, wr = IO.pipe
    case pid = fork
    when nil    # child
      wr.close
      STDIN.reopen(rd)
      exec(cmd)
      # NOT REACHED
    else
      begin
        rd.close
        yield(wr)
      ensure
        wr.close
        Process::waitpid(pid,0)
      end
    end
  end

  def print_list(list)
    list.each{|i, name, jname|
      puts "#{i}: #{jname}"
    }
  end

  ndtp = Ndtp.new(:Host=>NDTPSERVER, :Debug=>$DEBUG)
  list = ndtp.dic_list
  print_list(list)
  while line = Readline::readline("select> ", true)
    case line
    when /^$/
      print_list(list)
    when /^\d+$/
      dic_no = line.to_i
      if dic_names = list.assoc(dic_no)
        name = dic_names[2]
        while line = Readline::readline("#{name}> ", true)
          line.chomp!
          entries = ndtp.entry(dic_no, line)
          next if entries.empty?
          pipe_open(PAGER){|io|
            entries.each{|index, pos|
              buf = ndtp.consult(dic_no, pos)
              buf.gsub!(Ndtp::GAIJI_REGEX, "")
              buf.gsub!(Ndtp::REFERENCE_REGEX, "")
              io << buf << "━━━━━━━━━━━━\n"
            }
          }
        end
        puts ""
        print_list(list)
      end
    end
  end
  ndtp.close
end
