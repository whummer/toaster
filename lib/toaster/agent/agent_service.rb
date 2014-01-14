
$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), "..", "..")

require 'rubygems'
require 'toaster/util/config'
require 'toaster/util/docker'

include Toaster

$agent_port = 8385 if !$agent_port

puts "INFO: Configuring agent service."

# global initializations
require "toaster/test/test_runner"
$test_runners = {}

class MyThreadOut
  def write(out)
    local_out = Thread.current[:stdout]
    if local_out then
      local_out.write out 
    else
      STDOUT.write out
    end
  end
  def flush()
    local_out = Thread.current[:stdout]
    if local_out then
      local_out.flush
    else
      STDOUT.flush
    end
  end
  def method_missing(name, *args, &block)
    local_out = Thread.current[:stdout]
    if local_out then
      local_out.send(name, *args, &block)
    else
      STDOUT.send(name, *args, &block)
    end
  end
end
$stdout = MyThreadOut.new

## capture stdout using thread-local variable
require 'stringio'
module Kernel
  def capture_stdout(&block)
    out = StringIO.new
    Thread.start do
      begin
        Thread.current[:stdout] = out
        block.call
      ensure
        Thread.current[:stdout] = STDOUT
      end
    end.join
    return out.string
  end
end
##

def execute(cmd, silent=false)
	puts "Executing command: #{cmd}" if !silent
	output = `#{cmd}`
	retval = $?
	puts "return code: #{retval}, output: \n#{output}" if !silent
	return retval
end

# Start the actual server and create RPC bindings

require "xmlrpc/server"
require "toaster/api"
class ToasterAppServer < XMLRPC::Server
  def initialize(*args)
    super(*args)
    @app = Toaster::ToasterApp.new
    @methods = ["chefsolo", "clean", "download", "exec", "lxc", 
      "proto", "runchef", "runtest", "runtests", "testinit", "time"
    ]
    @methods.each do |method|
      add_handler(method) { |*args|
        out = capture_stdout do
          @app.send(method, *args)
        end
        out
      }
    end
  end
  def start()
    serve()
  end
end

server = ToasterAppServer.new($agent_port, "0.0.0.0")
server.start
