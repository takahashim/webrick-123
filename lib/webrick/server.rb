#
# server.rb -- GenericServer Class
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: server.rb,v 1.57 2002/09/21 12:23:37 gotoyuzo Exp $

require 'thread'
require 'socket'
require 'timeout'
require 'webrick/config'
require 'webrick/log'

module WEBrick

  class ServerError < StandardError; end

  class SimpleServer
    def SimpleServer.start
      yield
    end
  end

  class Daemon
    def Daemon.start
      exit!(0) if fork
      Process::setsid
      exit!(0) if fork
      Dir::chdir("/")
      File::umask(0)
      [ STDIN, STDOUT, STDERR ].each{|io|
        io.reopen("/dev/null", "r+")
      }
      yield if block_given?
    end
  end

  class GenericServer
    attr_reader :status, :config, :logger, :tokens, :listeners

    def initialize(config={}, default=Config::General)
      @config = default.dup.update(config)
      @status = :Stop
      @config[:Logger] ||= Log::new
      @logger = @config[:Logger]
      @listeners = []

      @tokens = SizedQueue.new(@config[:MaxClients])
      @config[:MaxClients].times{ @tokens.push(nil) }

      webrickv = "#{WEBrick::VERSION} (#{WEBrick::RELEASE_DATE})"
      rubyv = "#{RUBY_VERSION} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"
      @logger.info("WEBrick #{webrickv}")
      @logger.info("ruby #{rubyv}")

      listen()
    end

    def [](key)
      @config[key]
    end

    def listen
      return if @config[:DoNotListen]
      res = Socket::getaddrinfo(@config[:BindAddress], @config[:Port],
                                Socket::AF_UNSPEC,   # address family
                                Socket::SOCK_STREAM, # socket type
                                0,                   # protocol
                                Socket::AI_PASSIVE)  # flag
      last_error = nil
      res.each{|ai|
        begin
          @logger.debug("TCPServer.new(#{ai[3]}, #{@config[:Port]})")
          @listeners << TCPServer.new(ai[3], @config[:Port])
          Utils::set_close_on_exec(@listeners[-1])
        rescue => ex
          @logger.warn("TCPServer Error: #{ex}")
          last_error  = ex
        end
      }
      raise last_error if @listeners.empty?
    end

    def start(&block)
      raise ServerError, "already started." if @status != :Stop
      server_type = @config[:ServerType] || SimpleServer

      server_type.start{
        @logger.info \
          "#{self.type}#start: pid=#{$$} port=#{@config[:Port]}"
        start_hook()

        thgroup = ThreadGroup.new
        @status = :Running
        while @status == :Running
          begin
            if svrs = IO.select(@listeners, nil, nil, 2.0)
              svrs[0].each{|svr|
                @tokens.pop          # blocks while no token is there.
                sock = svr.accept
                sock.sync = true
                Utils::set_close_on_exec(sock)
                th = start_thread(sock, &block)
                th[:WEBrickThread] = true
                thgroup.add(th)
              }
            end
          rescue Errno::ECONNRESET, Errno::ECONNABORTED, Errno::EPROTO => ex
            msg = "#{ex.type}: #{ex.message}\n\t#{ex.backtrace[0]}"
            @logger.error msg
          rescue Errno::EBADF => ex  # IO::select causes by shutdown
          rescue => ex
            @logger.error ex
            break
          end
        end

        @logger.info "going to shutdown ..."
        thgroup.list.each{|th| th.join if th[:WEBrickThread] }
        stop_hook()
        @logger.info "#{self.type}#start done."
        @status = :Stop
      }
    end

    def stop
      if @status == :Running
        @status = :Shutdown
      end
    end

    def shutdown
      stop
      @listeners.each{|s| s.close }
      @listeners.clear
    end

    def run(sock)
      @logger.fatal "run() must be provided by user."
    end

    private

    def start_thread(sock, &block)
      Thread.start{
        begin
          Thread.current[:WEBrickSocket] = sock
          addr = sock.peeraddr
          @logger.debug "accept: #{addr[3]}:#{addr[1]}"
          accept_hook(sock)
          block ? block.call(sock) : run(sock)
        rescue ServerError, Errno::ENOTCONN => ex
          msg = "#{ex.type}: #{ex.message}\n\t#{ex.backtrace[0]}"
          @logger.error msg
        rescue Exception => ex
          @logger.error ex
        ensure
          Thread.current[:WEBrickSocket] = nil
          @logger.debug "close: #{addr[3]}:#{addr[1]}"
          sock.close
        end
        @tokens.push(nil)
      }
    end

    def accept_hook(sock) end
    def start_hook() end
    def stop_hook() end

  end    # end of GenericServer
end
