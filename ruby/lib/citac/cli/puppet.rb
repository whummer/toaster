require 'thor'
require_relative '../puppet/utils/graph_generation'
require_relative '../puppet/forge/client'

module Citac
  module CLI
    class Forge < Thor
      option :os
      option :tag, :aliases => :t
      option :owner, :aliases => :o
      option :limit, :aliases => :n
      desc 'search [--os <os>] [--tag|-t <tag>] [--owner|-o <owner>] [--limit|-n <count>] [<search keyword>]', 'Searches for Puppet modules.'
      def search(search_keyword = nil)
        query = Citac::Puppet::Forge::PuppetForgeModuleQuery.new
        query.os = options[:os]
        query.tag = options[:tag]
        query.owner = options[:owner]
        query.search_keyword = search_keyword

        query_options = {}
        query_options[:limit] = options[:limit].to_i if options[:limit]

        count = 0

        client = Citac::Puppet::Forge::PuppetForgeClient.new
        client.each_module query, query_options do |mod|
          puts "#{mod.full_name}\t#{mod.downloads} downloads\t#{mod.versions.length} versions"
          count += 1
        end

        puts
        puts "#{count} modules found"
      end
    end

    class Puppet < Thor
      desc 'graph [--dot|-d] <file> <file> <file...>', 'Generates dependency graphs for the given Puppet manifests.'
      option :dot, :type => :boolean, :aliases => :d, :desc => 'Generates DOT files as well if specified.'
      def graph(*files)
        files.each do |file|
          begin
            puts "Generating graphs for '#{file}' ..."
            Citac::Puppet::Utils::GraphGeneration.generate_graphs file, :generate_dot => options[:dot]
          rescue StandardError => e
            STDERR.puts "Failed to generate graphs for '#{file}': #{e}"
          end
        end
      end

      desc 'forge <command> <args...>', 'Interacts with the Puppet Forge.'
      subcommand 'forge', Forge
    end
  end
end