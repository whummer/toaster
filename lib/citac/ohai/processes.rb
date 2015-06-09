Ohai.plugin(:Processes) do
  provides 'processes'

  collect_data do
    begin
      require_relative '../commons/utils/processes'

      data = []

      Citac::Utils::Processes.each do |process|
        next if process.pid == Process.pid
        data << {:pid => process.pid, :name => process.name, :uid => process.uid, :cmd => process.cmdline}
      end

      processes data
    rescue StandardError => e
      processes "ERROR #{Time.now}: #{e}"
    end
  end
end