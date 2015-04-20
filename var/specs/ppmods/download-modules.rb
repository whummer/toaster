#!/usr/bin/env ruby

require 'fileutils'
require_relative '../../../lib/citac/commons/utils/colorize'
require_relative '../../../lib/citac/commons/utils/exec'

ARGV.each do |spec_dir|
  module_name = spec_dir.gsub /\.spec\/?/, ''
  modules_dir = File.join(spec_dir, 'files', 'modules')

  if Dir.exists?(modules_dir) && !Dir.entries(modules_dir).reject{|e| e == '.' || e == '..'}.empty?
    puts "Skipping #{module_name} because modules are already present."
    next
  end

  FileUtils.makedirs modules_dir
  puts "Fetching modules for #{module_name}...".yellow
  arguments = ['--modulepath', modules_dir, module_name]
  Citac::Utils::Exec.run 'puppet module install', :args => arguments, :stdout => :passthrough
end