

$tabs = [
  {"tests" => "Tests"},
  {"auto" => "Automations"},
  {"runs" => "Runs"},
  {"tasks" => "Tasks"},
  {"exec" => "Executions"},
  {"conv" => "Convergence"},
  {"graph" => "Graph"},
  {"gen" => "Generate"},
  {"lxc" => "LXC"},
  {"chef" => "Chef"},
  {"db" => "DB"},
  {"settings" => "Settings"}
]
$tab_loading_messages = {
  "lxc" => "loading<br/>(Requesting information from remote host, please be patient...)",
  "gen" => "loading<br/>(Requests can take a very long time, please avoid reloading this page...)",
  "default" => "loading"
}

def tab_index(tab)
  $tabs.each_with_index do |hash,ind|
    hash.each do |key,val|
      return ind if key == tab
    end
  end
  return -1
end

def run_post_rendering_tasks()
  require "toaster/db/cache"
  Toaster::Cache.flush()
end

def get_query_params(hash=nil)
  require 'uri'
  require 'cgi'

  hash = {} if !hash
  query_values = {}
  begin
    query = URI.parse(ENV['REQUEST_URI']).query
    query_values = query ? CGI::parse(query) : {}
  rescue
    query_values = params # for ruby on rails
  end
    query_values.each do |k,v|
      v = v.kind_of?(Array) ? v[0] : v.to_s
      if !hash.include?(k)
        hash[k] = v
      end
      if $user_params.include?(k)
        hash[k] = $user_params[k]
        if $user_params[k].nil?
          hash.delete(k)
        end
      end
    end
  return hash
end

def checkbox_checked(name)
  return param(name) != "" ? ' checked="checked"' : ""
end
def option_selected(name, value)
  return param(name) == value ? ' selected="selected"' : ""
end

def run_post_rendering_tasks()
  require "toaster/db/cache"
  Toaster::Cache.flush()
end

def clear_cache(only_if_cache_used=false)
  require "toaster/db/cache"
  return if only_if_cache_used && $session["do_cache"] != "1"
  load_cache()
  Toaster::Cache.clear()
end

def get_page_footer()
  require "toaster/db/cache"
  t1 = $start_time
  t2 = Time.new.to_f
  hits = Toaster::Cache.get_hits() || []
  misses = Toaster::Cache.get_misses() || []
  return "<div style=\"text-align: center; margin: auto; margin-top: 20px; font-size: 10px; color: #888888;\">" +
      "Page generated in #{format_float((t2-t1).abs, 3)} seconds.<br/>" +
      ($session["do_cache"] == "1" ? 
          ($session_loading_time ? "Loading session cache took #{format_float($session_loading_time, 3)} seconds. " : "") +
          "Cache hits: #{hits.size}, cache misses: #{misses.size}. " +
          "(<a href=\"#\" onclick=\"clear_cache_and_reload()\">clear and reload</a>)<br/>" :
          "") +
      #"cache hits: #{hits.join("<br/>\n")}, " +
      #"cache misses: #{misses.join("<br/>\n")}" +
      "</div>"
end

def get_link(hash=nil)
  hash1 = get_query_params()
  hash1['t'] = $current_page
  hash1.delete('p')
  hash = {} if !hash
  hash = hash1.merge(hash)
  if !hash['sessionID']
    hash['sessionID'] = $session['session_id']
  end
  link = "?"
  if hash.include?("p")
    link = "#{hash['p']}?"
    hash.delete('p')
  end
  count = 0
  hash.each do |k,v|
    if k.to_s.strip != "" && v.to_s.strip != ""
      link += "&amp;" if (count+=1) > 1
      link += "#{k}=#{v}"
    end
  end
  return link
end
def l(hash=nil) return get_link(hash) end

def db_id(id_str)
  require "toaster/db/db"
  return nil if !id_str || id_str.to_s == ""
  return Toaster::DB.instance.wrap_db_id(id_str)
end

def format_float(f, digits_after_comma=2)
  return "%.#{digits_after_comma}f" % f
end

def format_minutes(seconds)
  return to_minutes(seconds)
end
def to_minutes(seconds)
  return "n/a" if seconds.nil? || seconds.to_f.nan? || (seconds < 0)
  m = (seconds.to_f/60.0).floor
  s = (seconds - (m * 60.0)).round
  return "%02d:%02d" % [ m, s ]
end
  
def format_date(secs)
  return format_time(secs)
end
def format_time(secs)
  secs = secs.to_s.to_i
  Time.at(secs).strftime("%Y-%m-%d %H:%M:%S")
end

def escape_html(str)
  return esc_html(str)
end
def esc_html(str)
  return "" if !str
  return str.gsub("&","&amp;").gsub("<","&lt;").gsub(">","&gt;")
end

def init_cgi()
  $cgi = CGI.new("html4")
end
    
def init_session()
  require 'cgi/session/pstore'

  init_cgi() if !$cgi

  db_mgr = CGI::Session::PStore # one of FileStore/MemoryStore/PStore
  db_mgr = CGI::Session::FileStore # one of FileStore/MemoryStore/PStore
  t1 = Time.new
  begin
    $session = CGI::Session.new($cgi, 
      "session_key" => "sessionID",
      "prefix" => "rubysess.",
      "database_manager" => db_mgr)
    $session["foo"] # this will cause loading of the session data
    $session["session_id"] = $session.session_id
  rescue => ex
    $session = {}
  end
  $session_loading_time = Time.new - t1
end

$user_params = {}
def set_param(name, value)
  $user_params[name] = value
  if value.nil?
    $user_params.delete(name)
  end
end
def param(name, default="")
  return $user_params[name] if $user_params[name]
  return $cgi[name] if $cgi && $cgi[name] && $cgi[name].strip != ""
  p = get_query_params()[name]
  return p if p && p != ""
  return default
end

def redirect_if_necessary()
  query_values = get_query_params()
  if !query_values["sessionID"] || query_values["sessionID"].strip == ""
    init_session()
    puts "Location: ?sessionID=#{$session['session_id']}"
    puts ""
    puts "test"
    exit 0
  end
end

def render (path)
  content = File.read(File.expand_path(path))
  t = ERB.new(content)
  t.result(binding)
end

def init_mongo() 
  require "toaster/db/db"
  require "toaster/util/config"
  begin
    $session['mongoHost'] = Toaster::Config.get('mongodb.host') if $session['mongoHost'].to_s == ""
    $session['mongoPort'] = "27017" if $session['mongoPort'].to_s == ""
    $session['mongoDB'] = "toaster" if $session['mongoDB'].to_s == ""
    $session['mongoColl'] = "toaster" if $session['mongoColl'].to_s == ""
    $session['do_cache'] = "0" if $session['do_cache'].to_s == ""
    $connection = Mongo::Connection.new($session['mongoHost'], $session['mongoPort'].to_i)
    $db = $connection.db($session['mongoDB'])
    $coll = $db.collection($session['mongoColl'])
    Toaster::DB.DEFAULT_HOST = $session['mongoHost']
    Toaster::DB.DEFAULT_PORT = $session['mongoPort']
    Toaster::DB.DEFAULT_DB = $session['mongoDB']
    Toaster::DB.DEFAULT_COLL = $session['mongoColl']
    Toaster::DB.USE_CACHE = $session['do_cache'] == "1"
    if Toaster::DB.USE_CACHE
      puts "DEBUG: Loading DB cache..."
      load_cache()
    end
    #puts "DEBUG: Using connection #{DB.instance.connection.host}:#{DB.instance.connection.port} - " +
    #    "#{DB.instance.db.name}:#{DB.instance.collection.name}"
    return true
  rescue => ex
    $error = ex
    puts "WARN: Could not initialize connection: #{ex} - #{ex.backtrace}"
    return false
  end
end

def load_cache()
  require "toaster/db/cgi_session_cache"
  init_session() if !$session
  if !Toaster::Cache.get_cache()
    $cache = Toaster::CGISessionCache.new($session)
    Toaster::Cache.set_cache($cache)
  end
end

def get_execution_for_param(param_name = "exe")
  require "toaster/model/task_execution"
  return nil if param(param_name).strip == ""
  return Toaster::TaskExecution.load(db_id(param(param_name)))
end

def to_json(hash)
  return hash.to_json
end

def get_automation_for_param(param_name = "auto")
  require "toaster/model/automation"
  return nil if param(param_name).strip == ""
  return Toaster::Automation.load(db_id(param(param_name)))
end

def get_run_for_param(param_name = "run")
  require "toaster/model/automation_run"
  return nil if param(param_name).strip == ""
  return Toaster::AutomationRun.load(db_id(param(param_name)))
end

def get_task_for_param(param_name = "task")
  require "toaster/model/task"
  return Toaster::Task.load(db_id(param(param_name)))
end

def render_errors()
  str = ""
  if $error
    str = <<-EOH
    <div id="errorMsg" style="padding: 3px;">
    <span style="float: right; margin: 10px"><a onclick="$('#errorMsg').hide()" style="cursor: pointer">
    <img src="media/x.gif" alt="X" />
    </a></span>
    <div>
    <pre>Unable to render view: #{$error}
    #{esc_html($error.backtrace.join("\n"))}
    </pre>
    </div>
    </div>
    EOH
    $error = nil
  end
  return str
end

