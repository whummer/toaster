require 'set'
require 'thor'
require 'fileutils'
require_relative '../ioc'

module Citac
  module Main
    module CLI
      class Simple < Thor
        desc 'init', 'Initializes a new test.'
        def init
          raise 'Directory must be empty' if Dir.entries('.').reject{|e| e == '.' || e == '..'}.any?

          Dir.mkdir 'scripts'
          Dir.mkdir 'files'
          Dir.mkdir 'files/modules'

          FileUtils.touch 'scripts/default'
          write_metadata

          puts 'Initialized. Next steps:'
          puts ' 1. Edit Puppet test script "scripts/default" (site.pp).'
          puts ''
          puts ' 2. Add required Puppet modules (dependencies are automatically resolved).'
          puts '    $ citac add puppetlabs/stdlib'
          puts ''
          puts ' 3. Set operating system (use "citac os" for a list of supported operating systems).'
          puts '    $ citac os ubuntu-14.04'
        ensure
          ensure_proper_file_permissions
        end

        desc 'add <module> [<version>]', 'Adds a Puppet module and its dependencies to the test.'
        def add(module_name, version = nil)
          short_name = module_name.split('/').last
          raise 'Module already installed' if Dir.exists? File.join('files/modules', short_name)

          Dir.mktmpdir do |dir|
            script_path = File.join dir, 'download-module.sh'
            File.open script_path, 'w', :encoding => 'UTF-8' do |f|
              version_flags = version ? "--version #{version}" : ''
              f.puts '#!/bin/sh'
              f.puts 'cd /tmp/citac'
              f.puts "puppet module install #{module_name} #{version_flags} --modulepath /tmp/citac"
            end

            env = Citac::Main::ServiceLocator.environment_manager.find :spec_runner => 'puppet'
            Citac::Main::ServiceLocator.environment_manager.run env, script_path, :output => :passthrough

            Dir.entries(dir).each do |entry|
              next if entry == '.' || entry == '..'
              next unless File.directory? File.join(dir, entry)

              FileUtils.cp_r File.join(dir, entry), 'files/modules'
            end
          end
        ensure
          ensure_proper_file_permissions
        end

        desc 'os [<operating system>]', 'Shows or sets the test operating system.'
        def os(operating_system = nil)
          oss = Citac::Main::ServiceLocator.environment_manager.operating_systems 'puppet'

          if operating_system
            operating_system = Citac::Model::OperatingSystem.parse operating_system
            raise "Unknown operating system: #{operating_system}" unless oss.include? operating_system
            write_metadata operating_system
          end

          chosen_os = get_spec_os
          oss.sort_by{|o| o.to_s}.each do |supported_os|
            selection = supported_os == chosen_os ? '*' : ' '
            puts "#{selection} #{supported_os}"
          end

          unless chosen_os
            puts ''
            puts 'None selected.'
          end
        ensure
          ensure_proper_file_permissions
        end

        desc 'test', 'Starts or resume the test process.'
        def test
          spec, os = load_spec_os
          check_executed spec, os
          suite = ensure_test_suite_generated spec, os

          suite_results = Citac::Main::ServiceLocator.specification_repository.test_suite_results spec, os, suite

          aborted_test_cases = suite_results.aborted_test_cases.select { |c| (suite_results.test_case_results[c.id] || []).size > 3 }
          pending_test_cases = suite_results.pending_test_cases - aborted_test_cases

          if pending_test_cases.empty?
            puts 'No test cases to execute.  Run "citac results" to inspect found issues.'
          else
            pending_test_cases.each_with_index do |test_case, index|
              puts "Running test case \##{test_case.id} (#{index + 1} / #{pending_test_cases.size})...".yellow
              Citac::Utils::Exec.run 'citac', :args => ['test', 'exec', spec_name, os.to_s, suite.id, test_case.id], :output => :passthrough
            end

            puts 'Executed all test cases. Run "citac results" to inspect found issues.'
          end
        ensure
          ensure_proper_file_permissions
        end

        no_commands do
          def check_executed(spec, os)
            runs = Citac::Main::ServiceLocator.specification_repository.runs spec
            execs = runs.select {|r| r.operating_system == os && r.action == 'exec'}.to_a
            return if execs.any? {|r| r.exit_code == 0}


            if execs.size < 3
              puts 'Checking if script runs successfully in test environment...'.yellow

              Citac::Utils::Exec.run 'citac', :args => ['spec', 'exec', spec_name, os.to_s], :output => :passthrough

              run = Citac::Main::ServiceLocator.specification_repository.runs(spec).last
              raise 'Script failed to execute in test environment.' if run.exit_code != 0
            else
              raise 'Script failed to execute in test environment multiple times. Please resolve the error and run "citac reset".'
            end
          end

          def ensure_test_suite_generated(spec, os)
            suites = Citac::Main::ServiceLocator.specification_repository.test_suites spec, os
            if suites.empty?
              begin
                Citac::Utils::Exec.run 'citac', :args => ['test', 'gen', '-q', spec_name, os.to_s], :output => :passthrough
                suites = Citac::Main::ServiceLocator.specification_repository.test_suites spec, os
              rescue
                reset
                raise
              end
            end

            suites.first
          end
        end

        option :details, :aliases => :d, :type => :boolean, :desc => 'Enables error detail reporting.'
        desc 'results', 'Prints the test results.'
        def results
          spec, os, suite = load_spec_os_suite
          suite_results = Citac::Main::ServiceLocator.specification_repository.test_suite_results spec, os, suite

          finished = suite.test_cases.size - suite_results.pending_test_cases.size
          aborted = suite_results.aborted_test_cases.size

          puts "#{finished + aborted} out of #{suite.test_cases.size} test cases executed."
          puts

          if aborted > 0
            puts "#{aborted} permanent failures encountered".red
            puts '(run "citac results -d" to include error details)' unless options[:details]

            failing_steps = Set.new
            failing_steps_outputs = Hash.new {|h, k| h[k] = Set.new}

            suite_results.aborted_test_cases.each do |test_case|
              case_results = Citac::Main::ServiceLocator.specification_repository.test_case_results spec, os, suite, test_case
              case_results.each do |case_result|
                case_result.step_results.select{|r| r.step.type == :exec && r.result == :failure}.each do |failing_step_result|
                  step = failing_step_result.step.resource.to_s
                  failing_steps << step
                  if options[:details]
                    output = failing_step_result.output.lines.reject{|l| l.include? '[citac-puppet]'}.map{|l| "    #{l}"}.join
                    failing_steps_outputs[step] << output
                  end
                end
              end
            end

            failing_steps.sort.each do |s|
              puts "  - #{s}"
              if options[:details]
                puts
                failing_steps_outputs[s].each do |output|
                  puts output.pink
                  puts
                end
              end
            end
            puts
          end

          print 'Status: '
          overall_suite_result = suite_results.overall_suite_result
          case overall_suite_result
            when :failure
              puts 'Problems detected'.red
              puts '(run "citac results -d" to include error details)' unless options[:details]
            when :success
              puts 'No problems detected'.green
            when :unknown
              if finished + aborted < suite.test_cases.size
                puts 'Please complete all test cases first.'.yellow
              else
                puts 'There are failing test cases. Please resolve the error and run "citac reset" and "citac test" again.'.yellow
              end
            else
              raise "Unknown suite result: #{overall_suite_result}"
          end

          if overall_suite_result == :failure
            puts
            puts 'Problems:'

            idempotence_issues = Set.new
            idempotence_issues_details = Hash.new {|h, k| h[k] = Set.new}

            conflicts = Hash.new {|h, k| h[k] = Set.new}
            conflicts_details = Hash.new {|h, k| h[k] = Hash.new{|h2,k2| h2[k2] = Set.new}}

            suite.test_cases.each do |test_case|
              test_case_results = Citac::Main::ServiceLocator.specification_repository.test_case_results spec, os, suite, test_case
              test_case_results.each do |test_case_result|
                test_case_result.step_results.select{|sr| sr.step.type == :assert && sr.result == :failure}.each do |step_result|
                  resource = step_result.step.property.resources[0].to_s
                  case step_result.step.property.type
                    when :idempotence
                      idempotence_issues << resource
                      idempotence_issues_details[resource] << step_result.assertion_output if options[:details]
                    when :preservation
                      other = step_result.step.property.resources[1].to_s
                      conflicts[resource] << other
                      conflicts_details[resource][other] << step_result.assertion_output if options[:details]
                    else
                      raise "Unknown property type: #{step_result.step.property.type}"
                  end
                end
              end
            end

            (idempotence_issues + conflicts.keys).sort.each do |resource|
              if idempotence_issues.include? resource
                puts " - #{resource} is not idempotent"
                puts (idempotence_issues_details[resource].first || '').lines.map{|l| "   #{l}" }.join.pink if options[:details]
              end

              conflicts[resource].each do |non_preserved_resource|
                # do not print preservation errors because preservation cannot be tested without idempotence
                next if idempotence_issues.include? non_preserved_resource

                puts " - #{resource} does not preserve #{non_preserved_resource}"
                puts (conflicts_details[resource][non_preserved_resource].first || '').lines.map{|l| "   #{l}" }.join.pink if options[:details]
              end
            end
          end
        end

        desc 'reset', 'Clears all test results.'
        def reset
          FileUtils.rm_rf %w(graphs runs test-suites)
        end

        no_commands do
          def spec_name
            name = File.basename Dir.pwd
            raise 'Directory name must end with .spec' unless name.end_with? '.spec'

            name
          end

          def get_spec
            Citac::Main::ServiceLocator.specification_repository.get spec_name
          end

          def get_spec_os
            get_spec.operating_systems.first
          end

          def load_spec_os
            spec = get_spec
            os = get_spec_os

            raise 'No operating system chosen.' unless os

            return spec, os
          end

          def load_spec_os_suite
            spec, os = load_spec_os

            suites = Citac::Main::ServiceLocator.specification_repository.test_suites spec, os

            return spec, os, suites.first
          end

          def write_metadata(os = nil)
            oss = os ? "[\"#{os}\"]" : '[]'
            IO.write 'metadata.json', "{\n  \"type\": \"puppet\",\n  \"operating-systems\": #{oss}\n}\n", :encoding => 'UTF-8'
          end

          def ensure_proper_file_permissions
            stat = File::Stat.new Dir.pwd
            Citac::Utils::Exec.run 'chown', :args => ['-R', "#{stat.uid}:#{stat.gid}", Dir.pwd]
          end
        end
      end
    end
  end
end