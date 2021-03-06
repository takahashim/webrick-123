# 
# cgihandler.rb -- CGIHandler Class
#       
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#   
# $IPR: cgihandler.rb,v 1.24 2002/09/21 12:23:41 gotoyuzo Exp $

require 'rbconfig'
require 'tempfile'
require 'webrick/config'
require 'webrick/httpservlet/abstract'

module WEBrick
  module HTTPServlet

    class CGIHandler < AbstractServlet
      Ruby = File::join(::Config::CONFIG['bindir'],
                        ::Config::CONFIG['ruby_install_name'])
      CGIRunner = "#{Ruby} #{Config::LIBDIR}/httpservlet/cgi_runner.rb"

      def initialize(server, name)
        super
        @script_filename = name
        @tempdir = server[:TempDir]
        @cgicmd = "#{CGIRunner} #{server[:CGIInterpreter]}"
      end

      def do_GET(req, res)
        data = nil
        status = -1

        IO::popen(@cgicmd, "w"){|cgi_in|
          cgi_out = Tempfile.new("webrick.cgiout.", @tempdir)
          cgi_err = Tempfile.new("webrick.cgierr.", @tempdir)
          begin
            cgi_in.sync = true
            meta = req.meta_vars
            meta["SCRIPT_FILENAME"] = @script_filename
            meta["PATH"] = @config[:CGIPathEnv]
            dump = Marshal.dump(meta)

            cgi_in.write("%8d" % cgi_out.path.size)
            cgi_in.write(cgi_out.path)
            cgi_in.write("%8d" % cgi_err.path.size)
            cgi_in.write(cgi_err.path)
            cgi_in.write("%8d" % dump.size)
            cgi_in.write(dump)

            if req.body and req.body.size > 0
              cgi_in.write(req.body)
            end
            cgi_in.close
            status = $? >> 8
          ensure
            data = cgi_out.read
            cgi_out.close(true)
            if errmsg = cgi_err.read
              if errmsg.size > 0
                @logger.error("CGIHandler: #{@script_filename}:\n" + errmsg)
              end
            end 
            cgi_err.close(true)
          end
        }
        if status != 0
          @logger.error("CGIHandler: #{@script_filename} exit with #{status}")
        end

        data = "" unless data
        raw_header, body = data.split(/^[\xd\xa]+/on, 2) 
        raise HTTPStatus::InternalServerError,
          "The server encontered a script error." if body.nil?

        header = Hash.new
        field = nil
        raw_header.each{|line|
          line.chop!
          case line
          when /^([A-Za-z0-9_-]+):\s*(.*)$/o
            field, value = $1, $2
            field.downcase!
            header[field] = value
          when /^[\t ]+(.*)$/o
            raise HTTPStatus::InternalServerError,
              "The server encontered a script error." unless field
            header[field] << value
          when /^$/o
            break
          else
            raise HTTPStatus::InternalServerError,
              "The server encontered a script error."
          end
        }

        if /^(\d+)/ =~ header['status']
          res.status = $1.to_i
          header.delete('status')
        end
        header.each{|key, val| res[key] = val }
        res.body = body
      end
      alias do_POST do_GET
    end

  end
end
