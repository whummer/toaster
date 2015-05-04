require 'json'

require 'puppet/resource'
require 'puppet/application/resource'

class Puppet::Resource
  def __citac_to_hash
    {
        :type => type.to_s.downcase,
        :name => title,
        :parameters => parameters.dup
    }
  end
end

class Puppet::Application::Resource < Puppet::Application
  def main
    type, name, params = parse_args(command_line.args)

    resources = find_or_save_resources type, name, params
    data = resources.map { |r| r.prune_parameters(:parameters_to_include => @extra_params).__citac_to_hash }
    puts JSON.pretty_generate(data)
  end
end