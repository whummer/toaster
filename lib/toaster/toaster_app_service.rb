
$LOAD_PATH << File.join(File.expand_path(File.dirname(__FILE__)), "..")

# load dependencies using bundler
require "toaster/util/load_bundler"

# requires
require 'toaster/util/config'
require 'toaster/util/docker'

include Toaster

$service_port = 8385 if !$service_port

puts "INFO: Configuring service."

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
#require 'stringio'
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
class ToasterAppService < XMLRPC::Server
  def initialize(*args)
    super(*args)
    @app = Toaster::ToasterApp.new
    @methods = ["chefsolo", "clean", "download", "exec", "lxc", 
      "proto", "runchef", "runtest", "runtests", "testinit", "time"
    ]
    @methods.each do |method|
      add_handler(method) { |*args|
        exception = nil
        out = capture_stdout do
          begin
            @app.send(method, *args)
          rescue Object => ex
            exception = ex
          end
        end
        if exception
          puts "#{exception} - #{exception.backtrace.join("\n")}"
          puts "stdout: #{out}"
          puts "-----"
          raise exception
        end
        out
      }
    end
  end
  def start()
    serve()
  end
  
  def self.service_started?()
    output = `ps aux | grep -v "ps aux" | grep ruby | grep toaster_app_service`
    return output.strip != ""
  end
  
  def self.start_service()
    if !service_started?()
      dir = File.expand_path(File.dirname(__FILE__))
      Util.write("/tmp/toaster.service.loop.sh",
        "#!/bin/bash\n " +
        "cd #{dir}\n " +
        "while [ 1 ]; do\n " +
        "ruby toaster_app_service.rb do_start_service -v\n " +
        "done",
      true)
      `chmod +x /tmp/toaster.service.loop.sh`
      cmd = "cd #{dir} && screen -m -d bash /tmp/toaster.service.loop.sh"
      puts "INFO: Starting test service in the background (using screen), using port #{$service_port}."
      `#{cmd}`
    else
      puts "INFO: Another test service instance is already running on this host."
    end
  end
end


if ARGV.include?("do_start_service")
  puts "Starting service on port #{$service_port}"
  Toaster::Config.init_db_connection()
  server = ToasterAppService.new($service_port, "0.0.0.0")
  server.start
end
