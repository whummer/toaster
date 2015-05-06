require_relative '../utils/exec'

module Citac
  module Integration
    module Ohai
      def self.get_json(options = {})
        exec_opts = options.dup
        exec_opts[:args] = []

        plugin_dirs = options[:plugin_dirs] || []
        plugin_dirs.each {|d| exec_opts[:args] += ['-d', d]}

        result = Citac::Utils::Exec.run 'ohai', exec_opts
        result.stdout
      end
    end
  end
end