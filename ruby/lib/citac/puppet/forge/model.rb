module Citac
  module Puppet
    module Forge
      class PuppetForgeModuleQuery
        attr_accessor :os, :search_keyword, :tag, :owner

        def to_params
          result = {}
          result[:operatingsystem] = os if os
          result[:query] = search_keyword if search_keyword
          result[:tag] = tag if tag
          result[:owner] = owner if owner
          result
        end
      end

      class PuppetForgeModule
        def initialize(json)
          @json = json
        end

        def name; @json['name']; end
        def owner; @json['owner']['username']; end
        def full_name; "#{owner}-#{name}"; end

        def downloads; @json['downloads']; end
        def versions; @json['releases'].map{|x| x['version']}.to_a; end;
      end
    end
  end
end