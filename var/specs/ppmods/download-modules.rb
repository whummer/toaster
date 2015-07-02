#!/usr/bin/env ruby

require 'fileutils'
require_relative '../../../lib/citac/commons/utils/colorize'
require_relative '../../../lib/citac/commons/utils/exec'
require_relative '../../../lib/citac/commons/integration/docker'

ARGV.each do |spec_dir|
  spec_dir = File.absolute_path spec_dir
  module_name = spec_dir.split('/').last.gsub(/\.spec\/?/, '')
  module_name = module_name.split('-').take(2).join('-')
  modules_dir = File.join(spec_dir, 'files', 'modules')

  if Dir.exists?(modules_dir) && !Dir.entries(modules_dir).reject{|e| e == '.' || e == '..'}.empty?
    puts "Skipping #{module_name} because modules are already present."
    next
  end

  FileUtils.makedirs modules_dir
  puts "Fetching modules for #{module_name}...".yellow


  img = 'citac_environments/puppet:debian-7'
  cmd = ['puppet', 'module', 'install', '--modulepath', '/modules', module_name]
  mounts = [[modules_dir, '/modules', true]]

  Citac::Integration::Docker.run img, cmd, :mounts => mounts, :output => :passthrough
end