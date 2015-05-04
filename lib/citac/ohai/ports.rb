Ohai.plugin(:Ports) do
  provides 'ports'

  collect_data do
    begin
      require_relative '../commons/integration/netstat'

      open_ports = Citac::Integration::Netstat.get_open_ports
      open_ports.map! {|p| {:protocol => p.protocol, :port => p.port_nr}}
      ports open_ports
    rescue StandardError => e
      ports "ERROR #{Time.now}: #{e}"
    end
  end
end