Ohai.plugin(:Time) do
  provides 'time'

  collect_data do
    time Time.now.to_s
  end
end