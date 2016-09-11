require_relative '../../commons/utils/exec'

module Citac
  module Integration
    module Routes
      class RouteInfo
        attr_reader :destination, :gateway, :genmask, :flags, :metric, :ref, :use, :iface

        def initialize(destination, gateway, genmask, flags, metric, ref, use, iface)
          @destination = destination
          @gateway = gateway
          @genmask = genmask
          @flags = flags
          @metric = metric
          @ref = ref
          @use = use
          @iface = iface
        end

        def to_hash
          {
              :destination => @destination,
              :gateway => @gateway,
              :genmask => @genmask,
              :flags => @flags,
              :iface => @iface
          }
        end

        def self.parse4(line)
          pieces = line.strip.split /\s+/
          RouteInfo.new pieces[0], pieces[1], pieces[2], pieces[3], pieces[4].to_i, pieces[5].to_i, pieces[6].to_i, pieces[7]
        end

        def self.parse6(line)
          pieces = line.strip.split /\s+/
          RouteInfo.new pieces[0], pieces[1], nil, pieces[2], pieces[3].to_i, pieces[4].to_i, pieces[5].to_i, pieces[6]
        end
      end

      def self.get_ip4_routes
        result = Citac::Utils::Exec.run 'route', :args => %w(-A inet -n)
        result.stdout.lines.drop(2).to_a.sort.map{|l| RouteInfo.parse4 l}
      end

      def self.get_ip6_routes
        result = Citac::Utils::Exec.run 'route', :args => %w(-A inet6 -n)
        result.stdout.lines.drop(2).to_a.sort.map{|l| RouteInfo.parse6 l}
      end
    end
  end
end