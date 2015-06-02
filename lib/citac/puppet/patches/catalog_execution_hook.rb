require 'puppet/resource/catalog'
require_relative '../../commons/utils/colorize'

class Puppet::Resource::Catalog < Puppet::Graph::SimpleGraph
  alias_method :__citac_apply_original, :apply

  def apply(options = {})
    if host_config? && $__citac_steps
      __citac_apply_steps $__citac_steps, options
    else
      __citac_apply_original options
    end
  end

  def __citac_apply_steps(steps, options)
    steps.each_with_index do |step, index|
      if step.type == :assert
        puts "Step #{index + 1} / #{steps.size}: #{step}: #{step.property}...".yellow
      else
        puts "Step #{index + 1} / #{steps.size}: #{step}...".yellow
      end

      $citac_apply_single = true
      $citac_apply_single_resource_name = step.resource

      __citac_apply_original options
    end
  end
end