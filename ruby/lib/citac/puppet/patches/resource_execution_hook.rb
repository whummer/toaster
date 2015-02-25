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
    applied = true

    if intercepted
      if resource.noop?
        # Resource application is completely skipped if --noop flag is specified because Service resources
        # fail due to missing init scripts during a dry run on blank machines. Skipped application however
        # does not affect graph generation, which is the primary purpose of the dry runs.

        puts "[citac] Transaction: skipping '#{resource}' because of noop mode.".yellow
        applied = false
      elsif $citac_apply_single && $citac_apply_single_resource_name != resource.to_s
        puts "[citac] Transaction: skipping '#{resource}' because of single resource exec mode.".yellow
        applied = false
      else
        puts "[citac] Transaction: applying '#{resource}'...".yellow

        hexname = resource.to_s.encode('UTF-8').unpack('H*').first.downcase
        File.exist? "CITAC_RESOURCE_EXECUTION_START:#{hexname}:"
      end
    end

    return_value = nil
    return_value = __citac_original_apply resource, ancestor if applied

    if intercepted && applied
      failed = report.resource_statuses[resource.to_s].failed?

      File.exist? "CITAC_RESOURCE_EXECUTION_END:#{!failed}:"

      if failed
        puts "[citac] Transaction: failed to apply '#{resource}'.".red
      else
        puts "[citac] Transaction: applied '#{resource}'.".green
      end
    end

    return_value
  end
end