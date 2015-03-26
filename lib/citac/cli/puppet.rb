require 'fileutils'
require 'json'
require 'tempfile'
require 'thor'
require 'yaml'
require_relative 'ioc'
require_relative '../puppet/utils/graph_generation'
require_relative '../puppet/utils/trace_parser'
require_relative '../puppet/forge/client'
require_relative '../puppet/tasks/manifest_spec_generator'
require_relative '../puppet/tasks/module_spec_generator'
require_relative '../utils/exec'
require_relative '../utils/colorize'
require_relative '../model'

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

      option :resource, :aliases => :r, :desc => 'the single resource to execute'
      option :trace, :aliases => :t, :type => :boolean, :desc => 'enables system call tracing'
      option :tracefile, :aliases => :o, :desc => 'the file to write the trace output to (implicated -t)'
      option :modulepath, :desc => 'the path from which Puppet should load modules from'
      desc 'exec [-t [-o <tracefile>]] [-r <resource>] <manifest>', 'Executes a single or all resources of the given manifest.'
      def exec(manifest)
        trace = options[:trace] || options[:tracefile]

        puppet_args = []
        if options[:resource]
          puppet_args << 'apply-single'
          puppet_args << options[:resource]
        else
          puppet_args << 'apply'
        end
        puppet_args += ['--modulepath', options[:modulepath]] if options[:modulepath]
        puppet_args << manifest

        if trace
          Dir.mktmpdir do |dir|
            trace_file = File.join dir, 'citac_trace.txt'
            args = ['-f', '-o', trace_file, 'citac-puppet']
            args += puppet_args

            Citac::Utils::Exec.run 'strace', :args => args, :stdout => :passthrough

            traced_resources = Citac::Puppet::Utils::TraceParser.parse_file trace_file

            if options[:tracefile]
              json = JSON.pretty_generate traced_resources.map(&:to_h).to_a
              IO.write options[:tracefile], json, :encoding => 'UTF-8'
            end

            traced_resources.each do |traced_resource|
              puts
              puts "#{traced_resource.resource_name} (success = #{traced_resource.successful?}):"
              traced_resource.syscalls.each do |syscall|
                puts "  #{syscall}"
              end
            end
          end
        else
          Citac::Utils::Exec.run 'citac-puppet', :args => puppet_args, :stdout => :passthrough
        end
      end

      option :modulepath, :desc => 'the path from which Puppet should load modules from'
      option :print, :desc => 'flag whether puppet output should be printed to stdout or not', :aliases => :p, :type => :boolean
      desc 'testexec <manifest> <test case>', 'Executed the given test case based on the specified manifest.'
      def testexec(manifest, test_case_path)
        test_case = YAML.load_file test_case_path

        default_args = []
        default_args += ['--modulepath', options[:modulepath]] if options[:modulepath]
        default_args << manifest

        test_case_result = Citac::Model::TestCaseResult.new test_case
        test_case.steps.each_with_index do |step, index|
          puts "Executing step #{index + 1} / #{test_case.steps.size}: #{step}... "

          args = ['apply-single', step.resource] + default_args

          cmd = 'citac-puppet'
          cmd = 'citac-changetracker ' + cmd if step.type == :assert

          stdout = options[:print] ? :passthrough : :redirect
          result = Citac::Utils::Exec.run cmd, :args => args, :raise_on_failure => false, :stdout => stdout

          test_case_result.add_step_result step, result.success?, result.output

          if result.success?
            puts 'ok.'
          else
            puts 'fail.'
            STDERR.puts result.output
            break
          end
        end

        test_case_result.finish

        test_case_result_path = "#{File.basename(test_case_path, '.*')}_result.yml"
        IO.write test_case_result_path, test_case_result.to_yaml, :encoding => 'UTF-8'
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