=begin
= module WEBrick

WEBrick is a WEB server toolkit like bricks.  

== Constants

--- WEBrick::CR
--- WEBrick::LF
--- WEBrick::CRLF
--- WEBrick::VERSION
--- WEBrick::RELEASE_DATE

== class GenericServer

GenericServer is a generic server class.  A GenericServer instance is a
server which has:
  * thread based multiple access
  * configuration and logging utility

To use GenericServer, redefine `run' or invoke `start' with a block.
For example, an ECHO server which allows 5 connections on port 10000, 

  ----
    include WEBrick

    class EchoServer < GenericServer
      def run(sock)
        sock.each{|line| sock.write line}
      end
    end

    EchoServer.new(:Port => 10000).start
  ----

or instantly

  ----
    include WEBrick

    GenericServer.new(:Port => 10000).start {|sock|
      sock.each{|line| sock.write line}
    }
  ----

--- GenericServer::new(config={}, default=Config::General)

Creates and returns a (({GenericServer})) instance.  Options are specified
by ((|config|)), which overrides the second argument ((|default|)).  See
((<WEBrick::Config::General>)) for ((|default|)) values.

--- GenericServer#start
--- GenericServer#start { |accepted_socket| .... }

Starts the server.  When a GenericServer is started, some listening threads
are invoked, and the server goes a select-and-accept infinite loop until
((<GenericServer#stop>)) called.

(({GenericServer#start})) invokes its
((<GenericServer#config>))(({[:ServerType].start})) with giving a block
which runs worker threads to process accepted socket.  Those sockets are
accepted at (({GenericServer#start})) side thread and passed to a worker
thread through a queue.  ((<GenericServer#accept_hook>)) is invoked when
each thread get a socket.  If (({GenericServer#start})) is invoked with
given block, each worker thread executes the block by `(({yield}))';
Otherwise (({#run()})) is invoked.

      ---- Flowchart of GenericServer#start
   
        ,----------------------------------------------------.
        |                                                    |
        |          |                                         |
        |  queue = SizedQueue.new                            |
        |          |                  (worker thread)        |
        |          |------------------------.                |
        |          |(threading)             | <----------.   |
        |          |               sock = queue.pop      |   |
        |          |                #       |            |   |
        |          |                #  accept_hook(sock) |   |
        |          |                #       |            |   |
        |          |                #  run(sock)         |   |
        |          |                #    or yield(sock)  |   |
        |          | <---------.    #       |            |   |
        |          |           |    #   sock.close       |   |
        |  sock = s.accept     |    #       |            |   |
        |          |           |    #       `------------'   |
        |          |           |    #                        |
        |  queue.push(sock) ######### (passing accepted      |
        |          |           |       socket to thread      |
        |          `-----------'       through `queue')      |
        |                                                    |
        `----------------------------------------------------'

The number of threads are specified by
((<GenericServer#config>))(({[:StartThreads]})).

Invokes ((<Log#info>)) and ((<Log#debug>)) to
((<GenericServer#config>))(({[:Logger]})).

--- GenericServer#status

Returns (({:Stop})), (({:Running})) or (({:Shutdown})).  (({:Stop})) stands
for (({GenericServer#start})) has been finished, (({:Running})) for
(({GenericServer#start})) being active, and (({:Shutdown})) for to be going
to finish (({GenericServer#start})). 

--- GenericServer#config

Reterns the server's configuration.  This attibute is generated from 
arguments of ((<GenericServer::new>)). 

--- GenericServer#logger

Same to ((<GenericServer#config>))(({[:Logger]})). 

--- GenericServer#shutdown

Stops all threads. 

--- GenericServer#run(sock)

Just a dispatch for subclasses to be redefined or overrided. 

--- GenericServer#accept_hook(sock)

Is invoked at ((<GenericServer#start>)) after (({TCPServer#accept}))
before (({#run})) in a worker thread. 

--- GenericServer#start_hook()

Is invoked at ((<GenericServer#start>)) before worker threads started. 

--- GenericServer#stop()

Is invoked at ((<GenericServer#start>)) after worker threads finished. 
But does not close sockets for listening.

== class HTTPServer < ::WEBrick::GenericServer

HTTPServer is a HTTP server class, which features:

  * HTTP status exception control mechanism
  * HTTPRequest and HTTPResponse generating
  * Servlet based server construction - You can mount a servlet on a path
  * Default bundled servlet - FileHandler with DirectoryIndex, ERbHandler,
    and CGIHandler
  * Cookie handlings
  * BasicAuth
  * HTTPS functionality

For example, the following lists "hello, world" server on port 2000. 
Returns "hello, world" for "GET /hello" whereas "hello (again)" for 
"GET /hello/again".  

  ----
    #!/usr/local/bin/ruby
    require 'webrick'
    include WEBrick

    s = HTTPServer.new( :Port => 2000 )

    class HelloServlet < HTTPServlet::AbstractServlet
      def do_GET(req, res)
        res.body = "<HTML>hello, world.</HTML>"
        res['Content-Type'] = "text/html"
      end
    end

    # mount a servlet
    s.mount("/hello", HelloServlet)

    # servlet can be generated instantly
    s.mount_proc("/hello/again"){|req, res|
      res.body = "<HTML>hello (again)</HTML>"
      res['Content-Type'] = "text/html"
    }

    # Hit Ctrl-C to shutdown
    trap("INT"){ s.shutdown }

    s.start
  ----

--- HTTPServer::new(config={}, default=Config::HTTP)

Returns a new server instance with (({FileHandler})) mounted on "/"
(defalut).  If (({:DirectoryListEnable => boolean})) or (({:DocumentRoot =>
directory})) are given in its argument, (({FileHandler})) is mounted as
(({mount("/", FileHandler, directory, boolean)})).

See also ((<GenericServer::new>)), ((<HTTPServer#mount>)),
((<FileHandler::new>)) and ((<WEBrick::Config::HTTP>)).

--- HTTPServer#run(sock)

Body of each worker thread generated at ((<GenericServer#start>)).  For a
given accepted ((|sock|)), generates a pair of (({HTTPResponse})) and
(({HTTPRequest})), read socket and parses request, and then passes them to
(({HTTPSever#service})).  When an exception are rescued or
(({HTTPSever#service})) returns normally, setup response and send it.  This
method is an infinite loop while KEEP-ALIVE is established.

--- HTTPServer#service(req, res)

Does brokerage to servlet. That is, searchs and get instance of servlet
class accoding to ((|req|)) and then invoke (({servlet.service(req, res)})). 

--- HTTPServer#mount(dir, servlet, *options)

Associates a ((|servlet|)) class to a ((|dir|)).  ((|options|)) are used as
the second or folloing argument of (({get_instance})) which is called at
((<HTTPServer#service>)).

--- HTTPServer#mount_proc(dir, proc=nil, &block)

Associates a ((|block|)) to a ((|dir|)).  Internally,
(({ProcHandler.new(((|proc|)) || ((|block|)))})) is mounted.  

--- HTTPServer#unmount(dir)

Removes mounted servlet from ((|dir|)). 

--- HTTPServer#search_servlet(path)

Searches servlet associated to ((|path|)), and returns an array consists of
servlet, options, script name, path info. 

== class HTTPResponse

--- HTTPResponse#status
--- HTTPResponse#header
--- HTTPResponse#cookies
--- HTTPResponse#config
--- HTTPResponse#http_version
--- HTTPResponse#http_version=(str)
--- HTTPResponse#reason_phrase
--- HTTPResponse#reason_phrase=(str)
--- HTTPResponse#body
--- HTTPResponse#body=(str)

--- HTTPResponse::new(config)
--- HTTPResponse#status=(status)
--- HTTPResponse#[](field)
--- HTTPResponse#[]=(field, value)
--- HTTPResponse#send_response(socket)
--- HTTPResponse#send_header(socket)
--- HTTPResponse#send_body(socket)
--- HTTPResponse#to_s
--- HTTPResponse#set_redirect(status, url)
--- HTTPResponse#set_error(ex, backtrace=false)
--- HTTPResponse#keep_alive?
--- HTTPResponse#keep_alive=(val)

== class HTTPRequest

--- HTTPRequest#request_line
--- HTTPRequest#request_method
--- HTTPRequest#request_uri
--- HTTPRequest#http_version
--- HTTPRequest#path
--- HTTPRequest#query_string
--- HTTPRequest#raw_header
--- HTTPRequest#header
--- HTTPRequest#body
--- HTTPRequest#cookies
--- HTTPRequest#query
--- HTTPRequest#config
--- HTTPRequest#peeraddr

--- HTTPRequest#script_name
--- HTTPRequest#script_name=(str)
--- HTTPRequest#path_info
--- HTTPRequest#path_info=(str)

--- HTTPRequest::new(config)
--- HTTPRequest#parse(socket)
--- HTTPRequest#[](header_name)
--- HTTPRequest#each
--- HTTPRequest#keep_alive?
--- HTTPRequest#meta_vars

== class SimpleServer

class SimpleServer and ((<class Daemon>)) are buitin options for 
((<class GenericServer>))'s configuration which is associated 
to key (({:ServerType})).  (({SimpleServer})) is default server type. 

--- SimpleServer::start { .... }

Just does `(({yield}))' only.  Inveked from ((<GenericServer#start>)).  

== class Daemon

((<class SimpleServer>)) and class Daemon are buitin options for 
((<class GenericServer>))'s configuration which is associated 
to key (({:ServerType})).  (({Daemon})) is altenative server type. 

--- Daemon::start

Does daemon initiation as follows:

    ----
      fork do
        Process::setsid
        fork do
          Dir::chdir("/")
          File::umask(0)
          [ STDIN, STDOUT, STDERR ].each{|io|
            io.reopen("/dev/null", "r+")
          }
          yield
        end
      end
      exit!
    ----

Inveked from ((<GenericServer#start>)).  Never return. 

== module HTTPServlet
=== class FileHandler < AbstractServlet

--- FileHandler::add_handler(suffix, handler)
--- FileHandler::remove_handler(suffix)
--- FileHandler::new(server, root, show_dir=false)
--- FileHandler#do_GET(req, res)
--- FileHandler#do_POST(req, res)
--- FileHandler#search_handler(req, res)
--- FileHandler#exec_handler(req, res, handler_info)
--- FileHandler#set_local_file(req, res)
--- FileHandler#set_dir_list(req, res)

=== class ERbHandler < AbstractServlet

--- ERbHandler::new(server, name)
--- ERbHandler#do_GET(request, response)

=== class CGIHandler < AbstractServlet

--- CGIHandler::new(server, name)
--- CGIHandler#do_GET(req, res)

=== class AbstractServlet

--- AbstractServlet::require_path_info(val)
--- AbstractServlet::require_path_info?
--- AbstractServlet::get_instance(server, *options)
--- AbstractServlet::new(server, *options)
--- AbstractServlet#service(req, res)
--- AbstractServlet#do_GET(req, res)
--- AbstractServlet#do_HEAD(req, res)

== class URI
=== class InvalidURIError< StandardError

--- URI#scheme
--- URI#host
--- URI#port
--- URI#path
--- URI#query
--- URI#scheme=
--- URI#host=
--- URI#port=
--- URI#path=
--- URI#query=
--- URI::new(s)
--- URI#to_s
--- URI#inspect
--- URI::parse(s)

== class Log

--- Log#level
--- Log#time_format
--- Log#level=
--- Log#time_format=
--- Log::new(log_file=nil, level=nil)
--- Log#close
--- Log#log(level, msg)
--- Log#fatal(msg)
--- Log#error(msg)
--- Log#warn(msg)
--- Log#info(msg)
--- Log#debug(msg)
--- Log#fatal?
--- Log#error?
--- Log#warn?
--- Log#info?
--- Log#debug?
--- Log#backtrace(ex)

=== Constants
--- WEBrick::Log::DEBUG
--- WEBrick::Log::INFO
--- WEBrick::Log::WARN
--- WEBrick::Log::ERROR
--- WEBrick::Log::FATAL

== module HTTPUtils
--- HTTPUtils::normalize_path(path)
--- HTTPUtils::load_mime_types(file)
--- HTTPUtils::mime_type(filename, mime_tab)
--- HTTPUtils::escape(str)
--- HTTPUtils::unescape(str)
--- HTTPUtils::parse_query(str)

== class ServerError < StandardError

== module HTTPStatus

  * StandardError
    * HTTPStatus::Status
      * HTTPStatus::Info
          * HTTPStatus::Continue
          * HTTPStatus::SwitchingProtocols
      * HTTPStatus::Success
          * HTTPStatus::OK
          * HTTPStatus::Created
          * HTTPStatus::Accepted
          * HTTPStatus::NonAuthoritativeInformation
          * HTTPStatus::NoContent
          * HTTPStatus::ResetContent
          * HTTPStatus::PartialContent
      * HTTPStatus::Redirect
          * HTTPStatus::MultipleChoices
          * HTTPStatus::MovedPermanently
          * HTTPStatus::Found
          * HTTPStatus::SeeOther
          * HTTPStatus::NotModified
          * HTTPStatus::UseProxy
          * HTTPStatus::TemporaryRedirect
      * HTTPStatus::Error
        * HTTPStatus::ClientError
          * HTTPStatus::BadRequest
          * HTTPStatus::Unauthorized
          * HTTPStatus::PaymentRequired
          * HTTPStatus::Forbidden
          * HTTPStatus::NotFound
          * HTTPStatus::MethodNotAllowed
          * HTTPStatus::NotAcceptable
          * HTTPStatus::ProxyAuthenticationRequired
          * HTTPStatus::RequestTimeout
          * HTTPStatus::Conflict
          * HTTPStatus::Gone
          * HTTPStatus::LengthRequired
          * HTTPStatus::PreconditionFailed
          * HTTPStatus::RequestEntityTooLarge
          * HTTPStatus::RequestURITooLarge
          * HTTPStatus::UnsupportedMediaType
          * HTTPStatus::RequestRangeNotSatisfiable
          * HTTPStatus::ExpectationFailed
        * HTTPStatus::ServerError
          * HTTPStatus::InternalServerError
          * HTTPStatus::NotImplemented
          * HTTPStatus::BadGateway
          * HTTPStatus::ServiceUnavailable
          * HTTPStatus::GatewayTimeout
          * HTTPStatus::HTTPVersionNotSupported

--- HTTPStatus::reason_phrase(code)
--- HTTPStatus::info?(code)
--- HTTPStatus::success?(code)
--- HTTPStatus::redirect?(code)
--- HTTPStatus::error?(code)
--- HTTPStatus::client_error?(code)
--- HTTPStatus::server_error?(code)

=== Constants

--- WEBrick::HTTPStatus::RC_NON_AUTHORITATIVE_INFORMATION
--- WEBrick::HTTPStatus::RC_SEE_OTHER
--- WEBrick::HTTPStatus::RC_TEMPORARY_REDIRECT
--- WEBrick::HTTPStatus::RC_FORBIDDEN
--- WEBrick::HTTPStatus::RC_PROXY_AUTHENTICATION_REQUIRED
--- WEBrick::HTTPStatus::RC_LENGTH_REQUIRED
--- WEBrick::HTTPStatus::RC_UNSUPPORTED_MEDIA_TYPE
--- WEBrick::HTTPStatus::RC_SERVICE_UNAVAILABLE
--- WEBrick::HTTPStatus::RC_ACCEPTED
--- WEBrick::HTTPStatus::RC_PARTIAL_CONTENT
--- WEBrick::HTTPStatus::RC_FOUND
--- WEBrick::HTTPStatus::RC_PAYMENT_REQUIRED
--- WEBrick::HTTPStatus::RC_NOT_ACCEPTABLE
--- WEBrick::HTTPStatus::RC_GONE
--- WEBrick::HTTPStatus::RC_REQUEST_URI_TOO_LARGE
--- WEBrick::HTTPStatus::RC_BAD_GATEWAY
--- WEBrick::HTTPStatus::RC_SWITCHING_PROTOCOLS
--- WEBrick::HTTPStatus::RC_CREATED
--- WEBrick::HTTPStatus::RC_RESET_CONTENT
--- WEBrick::HTTPStatus::RC_MOVED_PERMANENTLY
--- WEBrick::HTTPStatus::RC_USE_PROXY
--- WEBrick::HTTPStatus::RC_NOT_FOUND
--- WEBrick::HTTPStatus::RC_BAD_REQUEST
--- WEBrick::HTTPStatus::RC_NOT_MODIFIED
--- WEBrick::HTTPStatus::RC_MULTIPLE_CHOICES
--- WEBrick::HTTPStatus::RC_NO_CONTENT
--- WEBrick::HTTPStatus::RC_OK
--- WEBrick::HTTPStatus::RC_CONTINUE
--- WEBrick::HTTPStatus::RC_HTTP_VERSION_NOT_SUPPORTED
--- WEBrick::HTTPStatus::RC_NOT_IMPLEMENTED
--- WEBrick::HTTPStatus::RC_EXPECTATION_FAILED
--- WEBrick::HTTPStatus::RC_REQUEST_ENTITY_TOO_LARGE
--- WEBrick::HTTPStatus::RC_CONFLICT
--- WEBrick::HTTPStatus::RC_METHOD_NOT_ALLOWED
--- WEBrick::HTTPStatus::RC_UNAUTHORIZED
--- WEBrick::HTTPStatus::RC_GATEWAY_TIMEOUT
--- WEBrick::HTTPStatus::RC_INTERNAL_SERVER_ERROR
--- WEBrick::HTTPStatus::RC_REQUEST_RANGE_NOT_SATISFIABLE
--- WEBrick::HTTPStatus::RC_PRECONDITION_FAILED
--- WEBrick::HTTPStatus::RC_REQUEST_TIMEOUT

== class HTTPServerError < ServerError
== module HTTPDate

--- HTTPDate::time2s(d)
--- HTTPDate::s2time(str)

=== Constants
--- WEBrick::HTTPDate::Timezone

== module HTTPAuth

--- HTTPAuth::_basic_auth(req, res, realm, req_field, res_field, err_type, block)
--- HTTPAuth::basic_auth(req, res, realm, &block)
--- HTTPAuth::proxy_basic_auth(req, res, realm, &block)

== module HTMLUtils
--- HTMLUtils::escape(string)

== class Cookie
--- Cookie#name
--- Cookie#version

--- Cookie#value
--- Cookie#domain
--- Cookie#path
--- Cookie#secure
--- Cookie#expires
--- Cookie#comment
--- Cookie#max_age

--- Cookie#value=
--- Cookie#domain=
--- Cookie#path=
--- Cookie#secure=
--- Cookie#expires=
--- Cookie#comment=
--- Cookie#max_age=

--- Cookie::new(name, value)
--- Cookie#to_s
--- Cookie::parse(str)

== module Config

=== Constants

--- WEBrick::Config::General

Default configuration for ((<class GenericServer>)). 
The following lists keys and corresponding values. 

  ----
    General = {
      :ServerName     => Utils::getservername,
      :Port           => nil,   # users MUST specifiy this!!
      :BindAddress    => nil,   # "0.0.0.0" or "::" or nil
      :ServerType     => nil,   # default: WEBrick::SimpleServer
      :StartThreads   => 5,     # number of working threads
      :Logger         => nil,   # default: WEBrick::Log.new
      :ServerSoftware => "WEBrick/#{WEBrick::VERSION} " +
                         "(Ruby/#{RUBY_VERSION}/#{RUBY_RELEASE_DATE})",
    }
  ----

See also: ((<Utils::getservername>)), ((<class SimpleServer>)), 
((<class Log>)). 

--- WEBrick::Config::HTTP

Default configuration for (({HTTPServe})), (({HTTPServlet})) 
etc.  The following lists keys and corresponding values. 

  ----
    HTTP = General.dup.update({
      :Port           => 80,
      :RequestTimeout => 30,
      :DocumentRoot   => nil,
      :HTTPVersion    => 1.1,
      :MimeTypes      =>
        HTTPUtils::load_mime_types(LIBDIR + "/mime.types"),
      :DirectoryIndex =>
        [ "index.html", "index.htm", "index.rhtml", "index.cgi" ],
      :DirectoryListEnable => true,
    })
  ----

See also ((<UTTPUtils::load_mime_types>)). 

== module Utils

--- Utils::su(user, group = nil)

--- Utils::getservername

$IPR: webrick.rd,v 1.9 2001/12/17 04:29:08 gotoken Exp $
=end
