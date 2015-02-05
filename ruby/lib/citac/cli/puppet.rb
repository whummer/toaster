require 'fileutils'
require 'json'
require 'thor'
require_relative '../puppet/utils/graph_generation'
require_relative '../puppet/forge/client'
require_relative '../utils/exec'
require_relative '../utils/colorize'

module Citac
  module CLI
    class Forge < Thor
      option :os
      option :tag, :aliases => :t
      option :owner, :aliases => :o
      option :limit, :aliases => :n
      desc 'search [--os <os>] [--tag|-t <tag>] [--owner|-o <owner>] [--limit|-n <count>] [<search keyword>]', 'Searches for Puppet modules.'
      def search(search_keyword = nil)
        query = Citac::Puppet::Forge::PuppetForgeModuleQuery.new
        query.os = options[:os]
        query.tag = options[:tag]
        query.owner = options[:owner]
        query.search_keyword = search_keyword

        query_options = {}
        query_options[:limit] = options[:limit].to_i if options[:limit]

        count = 0

        puts "downloads\tversions\tmodule"
        puts "---------\t--------\t------"
        Citac::Puppet::Forge::PuppetForgeClient.each_module query, query_options do |mod|
          puts "#{mod.downloads.to_s.rjust(9)}\t#{mod.versions.length.to_s.rjust(8)}\t#{mod.full_name}"
          count += 1
        end

        puts
        puts "#{count} modules found."
      end

      desc 'spec <module name>', 'Generates a file based test case stub for the given puppet module. The script needs to be edited.'
      def spec(module_name, version = nil)
        puts 'Setting up file structure...'

        spec_dir = "#{module_name}.spec"
        module_dir = File.join(spec_dir, 'files', 'modules')

        FileUtils.mkdir_p spec_dir
        FileUtils.mkdir_p File.join(spec_dir, 'scripts')
        FileUtils.mkdir_p module_dir

        puts 'Generating metadata...'

        mod = Citac::Puppet::Forge::PuppetForgeClient.get_module module_name
        metadata = {
            'type' => 'puppet',
            'operating-systems' => mod.operating_systems.map{|os| os.to_s},
            'puppet' => {
                'required-modules' => [module_name]
            }
        }

        IO.write File.join(spec_dir, 'metadata.json'), JSON.pretty_generate(metadata), :encoding => 'UTF-8'

        script_path = File.join(spec_dir, 'scripts', 'default.pp')
        IO.write script_path, "# #{mod.forge_url}\nTODO", :encoding => 'UTF-8'

        puts 'Fetching puppet modules...'

        arguments = ['--modulepath', module_dir]
        arguments += ['--version', version] if version
        arguments << module_name

        Citac::Utils::Exec.run 'puppet module install', :args => arguments, :stdout => :passthrough

        puts 'Done.'
        puts
        puts "IMPORTANT: Remember to edit '#{script_path}' to include the module properly.".yellow
      end
    end

    class Puppet < Thor
      desc 'graph [--dot|-d] <file> <file> <file...>', 'Generates dependency graphs for the given Puppet manifests.'
      option :dot, :type => :boolean, :aliases => :d, :desc => 'Generates DOT files as well if specified.'
      option :modulepath, :desc => 'Specifies the path from which Puppet should load modules from.'
      def graph(*files)
        files.each do |file|
          begin
            puts "Generating graphs for '#{file}' ..."

            opts = {
                :generate_dot => options[:dot],
                :modulepath => options[:modulepath]
            }
            Citac::Puppet::Utils::GraphGeneration.generate_graphs file, opts
          rescue StandardError => e
            STDERR.puts "Failed to generate graphs for '#{file}': #{e}"
          end
        end
      end

      desc 'forge <command> <args...>', 'Interacts with the Puppet Forge.'
      subcommand 'forge', Forge
    end
  end
end