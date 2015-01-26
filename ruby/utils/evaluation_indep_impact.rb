require_relative '../lib/citac/stg/stg'
require_relative '../lib/citac/specification/model'

def calculate_test_case_count(resource_count, indep_pairs)
  raise "Too many indep pairs: #{indep_pairs}. Maximum: #{resource_count / 2}" if indep_pairs > resource_count / 2

  spec = Citac::ConfigurationSpecification.new resource_count
  1.upto indep_pairs do |i|
    spec.add_dep 2 * i - 1, 2 * i
  end

  stg = Citac.generate_stg spec
  stg.path_count [], (1..resource_count).to_a
end

def compare_indep_pair_impact(resource_count)
  regular_count = calculate_test_case_count resource_count, 0
  puts "#{resource_count}\t0\t#{regular_count}"
  1.upto resource_count / 2 do |pair_count|
    test_count = calculate_test_case_count resource_count, pair_count
    puts "#{resource_count}\t#{pair_count}\t#{test_count}\t#{test_count * 100.0 / regular_count} %"
  end
end

1.upto 10 do |i|
  compare_indep_pair_impact i
  puts
  puts
end