require 'date'

Gem::Specification.new do |s|
  s.name = %q{cloud-toaster}
  s.version = File.exist?('VERSION') ? File.read('VERSION').strip : ""

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [	%q{Waldemar Hummer} ]
  s.date = DateTime.now.strftime("%Y-%m-%d")
  s.description = %q{A tool for automated testing and debugging of automation scripts (e.g., Chef).}
  s.email = [%q{hummer@infosys.tuwien.ac.at}]
  s.extra_rdoc_files = [
    "LICENSE",
    "Rakefile",
    "README.md",
    "VERSION"
  ]
  s.files = Dir.glob("lib/**/*") + Dir.glob("bin/*") +
		Dir.glob("bin/strace-4.8_patched/strace-x86_64") +
		Dir.glob("bin/strace-4.8_patched/strace-i686") +
		Dir.glob("chef/**/*") + Dir.glob("webapp/**/*") + 
		Dir.glob("config.json") + Dir.glob("Gemfile")

  deps = {
  	'bundler'		=> '~> 1.3',
  	# RUBY ON RAILS DEPENDENCIES 
	'rails'			=> '>= 0',		#, '4.0.2'
	'sqlite3'		=> '>= 0',
	'sass-rails'	=> '>= 0',		#, '~> 4.0.0'
	'uglifier'		=> '>= 0',		#, '>= 1.3.0'
	'coffee-rails'	=> '>= 0',		#, '~> 4.0.0'
	'jquery-rails'	=> '>= 0',
	'turbolinks'	=> '>= 0',
	'jbuilder'		=> '>= 0',		#, '~> 1.2'
	'devise'		=> '>= 0',
	'thin' 			=> '~> 1.6',		# 14-07-08: default version 2.0.0.pre is incompatible
	                      				# http://stackoverflow.com/questions/19579984/sinatra-server-wont-start-wrong-number-of-arguments

	# TOASTER DEPENDENCIES
	'hashdiff'		=> '>= 0', 		# diff hashes
	'json'			=> '>= 0',
	'aquarium'		=> '>= 0',
	'jsonpath'		=> '>= 0',
	'open4'			=> '>= 0',		# open processes with stdin/stdout
	'chef'			=> '>= 0',
	'ohai'			=> '>= 0',
	'rspec'			=> '>= 0',		# tests
	'ruby_parser'	=> '>= 0',		# parse Ruby code
	'bson'			=> '>= 0',
	'bson_ext'		=> '>= 0',
	'logger'		=> '>= 0',
	'thor'			=> '>= 0',		# CLI generator
	'tidy'			=> '>= 0',		# tidy XML library
	'diffy'  		=> '>= 0',		# comparing source files
	'mysql2'  		=> '>= 0',		# for DB access
	'therubyracer'	=> '>= 0',		# required by execjs
	'railties'		=> '>= 0',
	'activesupport'	=> '>= 0',
	'activerecord'	=> '>= 0'
  }

  #deps = File.read('Gemfile').scan(/^\s*gem\s*['"]([^'"]+)['"]/).uniq

  deps.each do |dep,version|
  	#dep = matched_dep[0]
    #version = matched_dep[2]
    #puts "#{dep} - #{version}"
    if version && !version.empty?
      s.add_runtime_dependency dep, version
      s.add_development_dependency dep, version
    else
      s.add_runtime_dependency dep
      s.add_development_dependency dep
    end

  end

  # further project dependencies:
  # * MySQL server
  # * Squid proxy server	# License: GNU GPL v2.0
  # * docker.io				# License: Apache v2.0
  # * strace				# License: BSD


  s.homepage = %q{https://github.com/whummer/toaster}
  s.licenses = [%q{Apache v2.0}]
  s.require_paths = [%q{lib}]
  s.rubygems_version = %q{1.8.9}
  s.summary = %q{Automated Testing/Debugging of Automation Scripts.}
  s.executables << "toaster"

end

