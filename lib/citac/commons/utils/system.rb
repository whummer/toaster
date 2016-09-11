require_relative 'exec'
require_relative 'processes'
require_relative '../integration/ifconfig'
require_relative '../integration/routes'
require_relative '../integration/netstat'

module Citac
  module Utils
    module System
      def self.uname
        result = Citac::Utils::Exec.run 'uname', :args => ['-a']
        result.stdout.strip
      end

      def self.hostname
        IO.read('/etc/hostname').strip
      end

      def self.fqdn
        result = Citac::Utils::Exec.run 'hostname', :args => ['--fqdn']
        result.stdout.strip
      end

      def self.mounts
        result = Citac::Utils::Exec.run 'mount'
        result.stdout.lines.map(&:strip).to_a.sort
      end

      def self.transient_state
        {
            'interfaces' => Citac::Integration::Ifconfig.get_interfaces,
            'routes' => {
                'ip4' => Citac::Integration::Routes.get_ip4_routes.map(&:to_hash),
                'ip6' => Citac::Integration::Routes.get_ip6_routes.map(&:to_hash)
            },
            'machine' => {
                'uname' => uname,
                'hostname' => hostname,
                'fqdn' => fqdn
            },
            'mounts' => mounts,
            'ports' => {
                'listening' => Citac::Integration::Netstat.get_open_ports.map(&:to_hash)
            },
            'processes' => {
                'running' => Citac::Utils::Processes.list.map(&:to_hash)
            }
        }
      end
    end
  end
end