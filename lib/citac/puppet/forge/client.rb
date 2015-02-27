require 'json'
require 'rest_client'

require_relative 'model'

module Citac
  module Puppet
    module Forge
      class PuppetForgeClient
        BASE_URL = 'https://forgeapi.puppetlabs.com/v3'

        def self.each_module(query, options = {})
          query ||= PuppetForgeModuleQuery.new
          page_size = options[:page_size] || 100
          sort_by = options[:sort_by] || 'downloads'
          limit = options[:limit]

          offset = 0
          count = 0
          loop do
            params = {:limit => page_size, :offset => offset, :sort_by => sort_by}
            params.merge! query.to_params

            response = RestClient.get "#{BASE_URL}/modules", :params => params
            json = JSON.parse response.to_str

            json['results'].each do |module_json|
              unless limit && count >= limit
                yield PuppetForgeModule.new module_json
                count += 1
              end
            end

            if json['pagination']['next'] && (!limit || count < limit)
              offset += page_size
            else
              break
            end
          end
        end

        def self.get_module(module_name)
          json = RestClient.get "#{BASE_URL}/modules/#{module_name}"
          PuppetForgeModule.new JSON.parse(json)
        end
      end
    end
  end
end
