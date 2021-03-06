#
# httpservlet.rb -- HTTPServlet Utility File
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2000, 2001 TAKAHASHI Masayoshi, GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: httpservlet.rb,v 1.20 2002/09/21 12:23:36 gotoyuzo Exp $

require 'webrick/httpservlet/abstract'
require 'webrick/httpservlet/filehandler'
require 'webrick/httpservlet/cgihandler'
require 'webrick/httpservlet/erbhandler'
require 'webrick/httpservlet/prochandler'

module WEBrick
  module HTTPServlet
    FileHandler.add_handler("cgi", CGIHandler)
    FileHandler.add_handler("rhtml", ERbHandler)
  end
end
