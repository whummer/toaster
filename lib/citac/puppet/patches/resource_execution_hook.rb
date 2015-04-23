require 'puppet/transaction'
require 'puppet/transaction/resource_harness'
require_relative '../../commons/integration/puppet/graph_cleanup'
require_relative '../../commons/utils/colorize'
require_relative '../../commons/logging'
require_relative '../../commons/integration/strace'

class Puppet::Transaction
  def __citac_intercepted_resource?(resource)
    catalog.host_config? && Citac::Integration::Puppet::GraphCleanup.is_real_resource?(resource)
  end

  alias_method :__citac_original_apply, :apply

  def apply(resource, ancestor = nil)
    intercepted = __citac_intercepted_resource? resource
    applied = true

    hexname = resource.to_s.encode('UTF-8').unpack('H*').first.downcase

    if intercepted
      if resource.noop?
        # Resource application is completely skipped if --noop flag is specified because Service resources
        # fail due to missing init scripts during a dry run on blank machines. Skipped application however
        # does not affect graph generation, which is the primary purpose of the dry runs.

        log_debug $prog_name, "Skipping '#{resource}' because of noop mode."
        applied = false
      elsif $citac_apply_single && $citac_apply_single_resource_name != resource.to_s
        log_debug $prog_name, "Skipping '#{resource}' because of single resource exec mode.".yellow
        applied = false
      else
        log_info $prog_name, "Applying '#{resource}'..."
      end
    end

    failed = nil
    return_value = nil
    if applied
      if $citac_apply_single_trace && intercepted
        trace_opts = {:syscalls => :file, :signals => :none}
        Citac::Integration::Strace.attach $citac_apply_single_trace_file, trace_opts do
          File.exist? "CITAC_RESOURCE_EXECUTION_START:#{hexname}:"

          return_value = __citac_original_apply resource, ancestor
          failed = report.resource_statuses[resource.to_s].failed?

          File.exist? "CITAC_RESOURCE_EXECUTION_END:#{!failed}:"
        end
      else
        File.exist? "CITAC_RESOURCE_EXECUTION_START:#{hexname}:" if intercepted

        return_value = __citac_original_apply resource, ancestor
        failed = report.resource_statuses[resource.to_s].failed?

        File.exist? "CITAC_RESOURCE_EXECUTION_END:#{!failed}:" if intercepted
      end
    end

    if intercepted && applied
      if failed
        log_error $prog_name, "Failed to apply '#{resource}'."
      else
        log_info $prog_name, "Applied '#{resource}'."
      end
    end

    return_value
  end
end