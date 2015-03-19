require 'rspec'
require_relative '../lib/citac'

RSpec.configure do |c|
  c.filter_run_excluding :explicit => true unless ENV['RUN_EXPLICIT'] == 'true'
end