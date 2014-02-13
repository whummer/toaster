Gem::Specification.new do |s|
  s.name = %q{toaster}
  s.version = File.exist?('VERSION') ? File.read('VERSION') : ""

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [	%q{Waldemar Hummer} ]
  s.date = %q{2013-10-05}
  s.description = %q{A tool for automated testing and debugging of automation scripts (e.g., Chef).}
  s.email = [%q{hummer@infosys.tuwien.ac.at}]
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md",
    "Rakefile",
    "VERSION"
  ]
  s.files = Dir.glob("lib/**/*") + Dir.glob("bin/*") +
		Dir.glob("bin/strace-4.8_patched/strace-x86_64") +
		Dir.glob("bin/strace-4.8_patched/strace-i686") +
		Dir.glob("chef/**/*") + Dir.glob("webapp/**/*")

  [
    "bson",						# License: Apache v2.0
    "bson_ext",					# License: Apache v2.0
    "chef",						# License: Apache v2.0
    "diffy",					# License: MIT
    "hashdiff",					# License: MIT
    "json",						# License: Ruby - https://www.ruby-lang.org/en/about/license.txt
    "jsonpath",					# ?
    "mongo",					# License: Apache v2.0
    "ohai",						# License: Apache v2.0
    "open4",					# License: Ruby
    "rails",					# License: MIT
    "rspec",					# License: MIT
    "ruby_parser",				# License: MIT
    "sexp_processor",			# License: MIT
    "sinatra",					# License: MIT
    "sinatra-contrib",			# License: custom (MIT?) - https://raw.github.com/sinatra/sinatra-contrib/master/LICENSE
    "tidy",						# License: Ruby
    "tidy-ext",					# License: Ruby
    "webrick"					# License: Ruby (?)
  ].each do |gem_dep|
    s.add_runtime_dependency gem_dep
  end

  # further project dependencies:
  # * MongoDB server		# License: GNU AGPL v3.0
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

