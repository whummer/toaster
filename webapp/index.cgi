#!/usr/local/rvm/bin/ruby-1.9.3-head
#!/usr/share/ruby-rvm/bin/ruby-1.9.3-head
# TODO: fix 

$start_time = Time.now.to_f

# imports and requires

#require 'rubygems'
require 'erb'

t1=Time.now.to_f
# make sure we always exit with code 0
Signal.trap('EXIT') { exit 0 }

# Import some utility functions
$LOAD_PATH << File.join(File.dirname(__FILE__))
require "util"
#require File.join(File.dirname(__FILE__), 'util.rb')
t2=Time.now.to_f

# output HTTP headers here...
#puts "set-cookie: mykey=myvalue"
redirect_if_necessary()

# required newline delimiter between HTTP header(s) and body
puts ""

begin

	# init CGI
	init_cgi()
	
	# init session management 
	# (don't load session for main 'template' page, i.e., when no page parameter is provided)
	init_session() if param('p').strip != ""
	t3=Time.now.to_f
	
	if $cgi['clearCache'] == "1"
		clear_cache()
	end
	
	# determine include file and output HTTP body

	$current_page = "main"
	if param('p').strip != ""
		page = param('p').strip
		if page.match(/[a-z_0-9A-Z]*/).to_s == page && File.exist?(File.join(File.dirname(__FILE__), "sections", "#{page}.html"))
			$current_page = page
		else
			$current_page = "error"
		end
	end
	include_file = "#{$current_page}.html"
	include_file_abs = File.join(File.dirname(__FILE__), "sections", include_file)

	file_contents = File.read(include_file_abs)
	file = ERB.new(file_contents)
	puts file.result()
	t4=Time.now.to_f
	#puts "#{t1-$start_time} - #{t2-t1} - #{t3-t2} - #{t4-t3} - "

	run_post_rendering_tasks()

rescue Exception => ex
	puts "<pre>Unable to render view: #{ex}"
	puts esc_html(ex.backtrace.join("\n"))
	puts "</pre>"
end