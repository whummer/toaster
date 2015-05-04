Ohai.plugin(:Packages) do
  provides 'packages'

  collect_data do
    begin
      require 'json'
      require_relative '../commons/utils/exec'

      result = Citac::Utils::Exec.run 'citac-puppet', :args => %w(resource package)
      data = JSON.parse result.stdout

      packages data
    rescue StandardError => e
      packages e.to_s
    end
  end
end