require 'thor'
require_relative '../../commons/logging'
require_relative '../../commons/model'
require_relative '../../commons/utils/serialization'
require_relative '../../commons/utils/colorize'
require_relative 'tasks/analyzation'
require_relative 'tasks/execution'
require_relative 'tasks/test'

module Citac
  module Agents
    module Puppet
      class CLI < Thor
        desc 'analyze [<dir>]', 'Analyzes the Puppet manifest in the given directory and stores the analyzation results in that directory.'
        def analyze(dir = '.')
          puts 'Generating dependency graph...'
          setup_workdir dir

          task = AnalyzationTask.new 'script'
          graph = task.execute :modulepath => 'modules'

          puts "Dependency graph generated: #{graph.nodes.size} nodes."
          IO.write 'dependencies.graphml', graph.to_graphml, :encoding => 'UTF-8'
        end

        option :resource, :aliases => :r, :desc => 'The resource to execute'
        option :stepwise, :aliases => :s, :type => :boolean, :desc => 'Enables stepwise execution.'
        desc 'exec [-r <resource name>] [<dir>]', 'Executes the Puppet manifest in the given directory and stores the run results in that directory.'
        def exec(dir = '.')
          setup_workdir dir

          if options[:stepwise]
            puts 'Generating dependency graph...'
            analyzation_task = AnalyzationTask.new 'script'
            graph = analyzation_task.execute :modulepath => 'modules'

            puts 'Determining execution order...'
            resources = graph.toposort.map(&:label)
          else
            resources = options[:resource]
          end

          task = ExecutionTask.new 'script', resources
          success = task.execute :modulepath => 'modules', :output => :passthrough
          if success
            puts 'Execution of configuration specification successful.'.green
          else
            puts 'Execution of configuration specification failed.'.red
            exit 1
          end
        end

        option :resource, :aliases => :r, :desc => 'The resource to execute'
        option :stepwise, :aliases => :s, :type => :boolean, :desc => 'Enables stepwise execution.'
        desc 'exec2 [-r <resource name>] [<dir>]', 'Executes the Puppet manifest twice in the given directory and stores the run results in that directory.'
        def exec2(dir = '.')
          exec dir
          exec dir
        end

        option :passthrough, :aliases => :p, :desc => 'Enables output passthrough of test steps'
        desc 'test [<dir>]', 'Executes the Puppet test case in the given directory and stores the test results in that directory.'
        def test(dir = '.')
          setup_workdir dir

          test_case = Citac::Utils::Serialization.load_from_file 'test_case.yml'

          output = options[:passthrough] ? :passthrough : :redirect

          task = TestTask.new 'script', test_case
          task.file_exclusion_patterns = load_file_exclusion_patterns dir
          task.state_exclusion_patterns = load_state_exclusion_patterns dir
          test_case_result = task.execute :modulepath => 'modules', :output => output

          Citac::Utils::Serialization.write_to_file test_case_result, 'test_case_result.yml'
        end

        no_commands do
          def setup_workdir(dir)
            workdir = File.expand_path dir

            log_debug 'citac-agent-puppet', "Setting workdir to '#{workdir}'..."
            Dir.chdir workdir
          end

          def load_file_exclusion_patterns(dir)
            path = File.join dir, 'excluded_files.yml'
            return [] unless File.exists? path

            patterns = Citac::Utils::Serialization.load_from_file path
            patterns.map {|p| Regexp.new p}.to_a
          end

          def load_state_exclusion_patterns(dir)
            path = File.join dir, 'excluded_states.yml'
            return [] unless File.exists? path

            patterns = Citac::Utils::Serialization.load_from_file path
            processed = patterns.map do |pattern|
              if pattern.respond_to? :map
                pattern.map{|p| Regexp.new p}.to_a
              else
                Regexp.new pattern
              end
            end

            processed.to_a
          end
        end
      end
    end
  end
end