require 'puppet/transaction'
require 'puppet/transaction/resource_harness'
require_relative '../utils/graph_cleanup'
require_relative '../../utils/colorize'

class Puppet::Transaction
  def __citac_intercepted_resource?(resource)
    catalog.host_config? && Citac::Puppet::Utils::GraphCleanup.is_real_resource?(resource)
  end

  alias_method :__citac_original_apply, :apply

  def apply(resource, ancestor = nil)
    intercepted = __citac_intercepted_resource? resource
    puts "[citac] Transaction: applying '#{resource}'...".yellow if intercepted

    return_value = __citac_original_apply resource, ancestor

    if intercepted
      failed = report.resource_statuses[resource.to_s].failed?
      if failed
        puts "[citac] Transaction: failed to apply '#{resource}'.".red
      else
        puts "[citac] Transaction: applied '#{resource}'.".green
      end
    end

    return_value
  end
end