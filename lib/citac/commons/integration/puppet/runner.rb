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

        if resource_name = options[:resource]
          args += ['apply-single', resource_name]
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