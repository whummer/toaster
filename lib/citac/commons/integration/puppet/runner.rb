module Citac
  module Integration
    module Puppet
      def self.apply(manifest_path, options = {})
        exec_opts = options.dup
        exec_opts[:args] = apply_args manifest_path, options

        Citac::Utils::Exec.run 'citac-puppet', exec_opts
      end

      def self.apply_args(manifest_path, options = {})
        args = []

        if options[:resource]
          args += ['apply-single', options[:resource]]
          args += ['--trace', options[:trace_file]] if options[:trace_file]
        elsif options[:test_case_file]
          raise 'Test case result file path not provided.' unless options[:test_case_result_file]
          raise 'Test settings file path not provided' unless options[:settings_file]
          args += ['apply-test-case', options[:test_case_file], options[:test_case_result_file], options[:settings_file]]
        else
          args << 'apply'
        end

        args << '--noop' if options[:noop]
        args << '--graph' if options[:graph]
        args += ['--modulepath', options[:modulepath]] if options[:modulepath]
        args += ['--graphdir', options[:graphdir]] if options[:graphdir]
        args << manifest_path

        args
      end
    end
  end
end