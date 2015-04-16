require 'thor'
require_relative '../ioc'
require_relative '../../commons/integration/puppet/forge'
require_relative '../tasks/puppet/manifest_spec_generator'
require_relative '../tasks/puppet/module_spec_generator'

module Citac
  module Main
    module CLI
      class Puppet < Thor
        def initialize(*args)
          super
          @env_mgr = ServiceLocator.environment_manager
        end

        option :os
        option :tag, :aliases => :t
        option :owner, :aliases => :o
        option :limit, :aliases => :n
        option :quiet, :aliases => :q
        desc 'search [--os <os>] [-t <tag>] [-o <owner>] [-n <count>] [-q] [<search keyword>]', 'Searches the Puppet Forge for modules.'
        def search(search_keyword = nil)
          query = Citac::Puppet::Forge::PuppetForgeModuleQuery.new
          query.os = options[:os]
          query.tag = options[:tag]
          query.owner = options[:owner]
          query.search_keyword = search_keyword

          query_options = {}
          query_options[:limit] = options[:limit].to_i if options[:limit]

          unless options[:quiet]
            count = 0

            puts "downloads\tversions\tmodule"
            puts "---------\t--------\t------"
          end

          Citac::Puppet::Forge::PuppetForgeClient.each_module query, query_options do |mod|
            if options[:quiet]
              puts mod.full_name
            else
              puts "#{mod.downloads.to_s.rjust(9)}\t#{mod.versions.length.to_s.rjust(8)}\t#{mod.full_name}"
              count += 1
            end
          end

          unless options[:quiet]
            puts
            puts "#{count} modules found."
          end
        end

        desc 'spec <module name or manifest>', 'Generates a file based test case stub for the given puppet module or manifest.'
        def spec(module_name_or_manifest_path, version = nil)
          if module_name_or_manifest_path.end_with? '.pp' || File.exists?(module_name_or_manifest_path)
            generator = Citac::Main::Tasks::Puppet::ManifestSpecificationGenerator.new @env_mgr
            generator.generate module_name_or_manifest_path
          else
            generator =Citac::Main::Tasks::Puppet::ModuleSpecificationGenerator.new
            generator.generate module_name_or_manifest_path, version
          end
        end
      end
    end
  end
end