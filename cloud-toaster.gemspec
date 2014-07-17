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

  deps = File.read('Gemfile').scan(/^\s*gem\s*['"]([^'"]+)['"]/).uniq
  deps.each do |matched_dep|
  	dep = matched_dep[0]
    version = matched_dep[2]
    if version && !version.empty?
      s.add_runtime_dependency dep, version
    else
      s.add_runtime_dependency dep
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

