
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

$LOAD_PATH << File.join(File.dirname(__FILE__), "..")
require 'rubygems'
require 'sinatra/base'
require 'toaster/util/config'
require 'sinatra/reloader' # for reloading ruby files without restarting the server

$LOAD_PATH << File.join(File.dirname(__FILE__), "..", "..", "webapp")
require "util"

# initializations
$cgi = {}
init_session()
require 'toaster/db/db'
require 'toaster/db/ram_cache'
include Toaster
DB.USE_CACHE = true
Cache.set_cache(RAMCache.new)
AUTHENTICATIONS = { 
  #"toaster" => "toaster!" 
}
WEB_ROOT = File.join(File.dirname(__FILE__), "..", "..", "webapp")

# Sinatra (REST Web server) configuration
puts "INFO: Configuring REST Web server."
class WebUI < Sinatra::Base

  set :environment => :production
  set :port => 8080
  set :bind => '0.0.0.0'
  set :show_exceptions => true
  set :sessions => true
  set :root => WEB_ROOT
  set :static => true
  set :public_folder => WEB_ROOT
  set :run => true
  set :server  => %w[thin mongrel webrick]
  register Sinatra::Reloader
  also_reload File.join(File.expand_path(File.dirname(__FILE__)), "..")

  if AUTHENTICATIONS && !AUTHENTICATIONS.empty?
    use Rack::Auth::Basic, "Restricted Area" do |username, password|
      AUTHENTICATIONS[username] == password
    end
  end

  before do
    #content_type 'text/plain'
  end
  
  dir = File.join(WEB_ROOT, "sections")
  Dir["#{dir}/*.html"].each do |path|
    path = path.gsub(/.*\/([a-z_]+)\.html/, '\1')

    # define "GET" path for sub-pages
    get "/#{path}" do
  
      $start_time = Time.now.to_f
      ENV['REQUEST_URI'] = request.url
      $cgi = params
  
      $current_page = path
      include_file = "#{$current_page}.html"
      include_file_abs = File.join(WEB_ROOT, "sections", include_file)
  
      begin
        file_contents = File.read(include_file_abs)
        file = ERB.new(file_contents)
        return file.result()
      rescue Object => exc
        return "An error has occurred: <pre>#{exc} - #{exc.backtrace.join("\n")}</pre>"
      end
  
    end

    # define "POST" path for sub-pages
    post "/#{path}" do
  
      $start_time = Time.now.to_f
      ENV['REQUEST_URI'] = request.url
      $cgi = params

      $current_page = path
      include_file = "#{$current_page}.html"
      include_file_abs = File.join(WEB_ROOT, "sections", include_file)

      begin
        file_contents = File.read(include_file_abs)
        file = ERB.new(file_contents)
        return file.result()
      rescue Object => exc
        return "An error has occurred: <pre>#{exc} - #{exc.backtrace.join("\n")}</pre>"
      end

    end

  end

  post "/" do
    if params["p"]
      # redirect
      params_without_page = params.dup
      params_without_page.delete("p")
      redirect to("/#{params['p']}?#{params_without_page.map{|k,v| "#{k}=#{v}"}.join('&')}")
    end
  end

  get "/" do
    $start_time = Time.now.to_f
    ENV['REQUEST_URI'] = request.url
    $cgi = params
  
    if params["p"]
      # redirect
      params_without_page = params.dup
      params_without_page.delete("p")
      redirect to("/#{params['p']}?#{params_without_page.map{|k,v| "#{k}=#{v}"}.join('&')}")
    else
      include_file_abs = File.join(WEB_ROOT, "sections", "main.html")
      file_contents = File.read(include_file_abs)
      file = ERB.new(file_contents)
      return file.result()
    end
  end

  run! if app_file == $0
end
