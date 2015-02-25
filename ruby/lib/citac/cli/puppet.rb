require 'fileutils'
require 'json'
require 'tempfile'
require 'thor'
require_relative 'ioc'
require_relative '../puppet/utils/graph_generation'
require_relative '../puppet/utils/trace_parser'
require_relative '../puppet/forge/client'
require_relative '../puppet/tasks/manifest_spec_generator'
require_relative '../puppet/tasks/module_spec_generator'
require_relative '../utils/exec'
require_relative '../utils/colorize'

module Citac
  module CLI
    module PuppetSubcommands
      class Forge < Thor
        option :os
        option :tag, :aliases => :t
        option :owner, :aliases => :o
        option :limit, :aliases => :n
        option :quiet, :aliases => :q
        desc 'search [--os <os>] [--tag|-t <tag>] [--owner|-o <owner>] [--limit|-n <count>] [--quiet|-q] [<search keyword>]', 'Searches for Puppet modules.'
        def search(search_keyword = nil)
          query = Citac::Puppet::Forge::PuppetForgeModuleQuery.new
          query.os = options[:os]
          query.tag = options[:tag]
          query.owner = options[:owner]
          query.search_keyword = search_keyword

          query_options = {}
          query_options[:limit] = options[:limit].to_i if options[:limit]

          unless options[:quiet]
            count = 0

            puts "downloads\tversions\tmodule"
            puts "---------\t--------\t------"
          end

          Citac::Puppet::Forge::PuppetForgeClient.each_module query, query_options do |mod|
            if options[:quiet]
              puts mod.full_name
            else
              puts "#{mod.downloads.to_s.rjust(9)}\t#{mod.versions.length.to_s.rjust(8)}\t#{mod.full_name}"
              count += 1
            end
          end

          unless options[:quiet]
            puts
            puts "#{count} modules found."
          end
        end
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
            exit 1
          end
        end
      end

      option :trace, :aliases => :t, :type => :boolean, :desc => 'enables system call tracing'
      option :tracefile, :aliases => :o, :desc => 'the file to write the trace output to (implicated -t)'
      desc 'exec <manifest> <resource>', 'Executes a single resource of the given manifest.'
      def exec(manifest, resource)
        trace = options[:trace] || options[:tracefile]

        if trace
          Dir.mktmpdir do |dir|
            trace_file = File.join dir, 'citac_trace.txt'
            Citac::Utils::Exec.run 'strace', :args => ['-f', '-o', trace_file, 'citac-puppet', 'apply-single', resource, manifest], :stdout => :passthrough

            traced_resources = Citac::Puppet::Utils::TraceParser.parse_file trace_file

            if options[:tracefile]
              json = JSON.pretty_generate traced_resources.map!(&:to_h)
              IO.write options[:tracefile], json, :encoding => 'UTF-8'
            end

            puts
            traced_resources.each do |trace|
              puts "#{trace.resource_name} (success = #{trace.successful?}):"
              trace.syscalls.each do |syscall|
                puts "  #{syscall}"
              end
            end
          end
        else
          Citac::Utils::Exec.run 'citac-puppet apply-single', :args => [resource, manifest], :stdout => :passthrough
        end
      end

      desc 'spec <module or manifest>', 'Generates a file based test case stub for the given puppet module or manifest.'
      def spec(module_name_or_manifest_path, version = nil)
        if module_name_or_manifest_path.end_with? '.pp'
          env_mgr = ServiceLocator.environment_manager
          generator = Citac::Puppet::Tasks::ManifestSpecificationGenerator.new env_mgr
          generator.generate module_name_or_manifest_path
        else
          generator = Citac::Puppet::Tasks::ModuleSpecificationGenerator.new
          generator.generate module_name_or_manifest_path, version
        end
      end

      desc 'forge <command> <args...>', 'Interacts with the Puppet Forge.'
      subcommand 'forge', PuppetSubcommands::Forge
    end
  end
end