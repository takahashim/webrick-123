#
# compat.rb -- cross platform compatibility
#
# Author: IPR -- Internet Programming with Ruby -- writers
# Copyright (c) 2002 GOTOU Yuuzou
# Copyright (c) 2002 Internet Programming with Ruby writers. All rights
# reserved.
#
# $IPR: compat.rb,v 1.5 2002/09/21 12:23:35 gotoyuzo Exp $

module Errno
  class EPROTO       < SystemCallError; end
  class ECONNRESET   < SystemCallError; end
  class ECONNABORTED < SystemCallError; end
end
