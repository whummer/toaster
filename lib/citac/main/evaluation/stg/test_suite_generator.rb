require_relative '../../../commons/model'
require_relative '../../../commons/utils/colorize'
require_relative '../../../commons/utils/exec'
require_relative 'suite_spec'

module Citac
  module Main
    module Evaluation
      module STG
        class TestSuiteGenerator
          def initialize(repo, env_mgr)
            @repo = repo
            @env_mgr = env_mgr
          end

          def run
            start_time = Time.now

            @repo.each_spec do |spec_name|
              spec = @repo.get spec_name
              spec.operating_systems.each do |os|
                begin
                  next unless @repo.has_dependency_graph? spec, os

                  env = @env_mgr.find :spec_runner => spec.type, :operating_system => os, :no_raise => true
                  next unless env

                  run_suite_os spec, os
                rescue StandardError => e
                  puts "Failed to handle #{spec_name} / #{os}: #{e}".red
                end
              end
            end

            end_time = Time.now
            puts "Finished in #{end_time - start_time} seconds"
          end

          def run_suite_os(spec, os)
            suites = @repo.test_suites spec, os

            existing = suites.map{|s| SuiteSpec.from_suite s}
            remaining = suite_specs.reject{|s| existing.include? s}

            return if remaining.empty?

            dg = @repo.dependency_graph spec, os
            puts "Creating STG test suites for #{spec.name} on #{os} (#{dg.nodes.size} resources)..."
            start_time = Time.now

            remaining.each do |suite_spec|
              begin
                run_suite_spec spec, os, suite_spec
              rescue StandardError => e
                puts "Failed to generate #{spec.name} / #{os} / #{suite_spec}: #{e}".red
              end
            end

            end_time = Time.now
            puts "Done in #{end_time - start_time} seconds."
          end

          def run_suite_spec(spec, os, suite_spec)
            $stdout.print "  - #{suite_spec}\t\t"
            $stdout.flush

            args = %w(test gen -t stg -q)
            args += ['-c', suite_spec.coverage]
            args += ['-l', suite_spec.edgelimit]
            args += ['-x', suite_spec.expand]
            args += ['-e'] if suite_spec.alledges
            args += [spec.name, os]

            start_time = Time.now
            Citac::Utils::Exec.run 'citac', :args => args
            end_time = Time.now

            $stdout.puts " done (#{end_time - start_time} seconds)."
            $stdout.flush
          end

          def suite_specs
            [
                # base
                SuiteSpec.new(:edge, 3, 0, false),

                # visit boundaries
                SuiteSpec.new(:edge, 1, 0, false),
                SuiteSpec.new(:edge, 10, 0, false),
                SuiteSpec.new(:edge, 100, 0, false),

                # expansions
                SuiteSpec.new(:edge, 3, 1, false),
                SuiteSpec.new(:edge, 3, 2, false),

                # add edges
                SuiteSpec.new(:edge, 3, 0, true),

                # coverage
                SuiteSpec.new(:path, 1, 0, false),
                SuiteSpec.new(:path, 3, 0, false),
                SuiteSpec.new(:path, 10, 0, false),
                SuiteSpec.new(:path, 100, 0, false)
            ]
          end
        end
      end
    end
  end
end