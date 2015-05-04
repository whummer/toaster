Ohai.plugin(:Services) do
  provides 'services'

  collect_data do
    begin
      require 'json'
      require_relative '../commons/utils/exec'

      result = Citac::Utils::Exec.run 'citac-puppet', :args => %w(resource service)
      data = JSON.parse result.stdout

      services data
    rescue StandardError => e
      services "ERROR #{Time.now}: #{e}"
    end
  end
end