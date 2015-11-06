require 'puppet'
require 'puppet/parser'

class Puppet::Parser::AST::Hostclass < Puppet::Parser::AST::TopLevelConstruct
  def each
    yield code
  end
end

$env = Puppet::Node::Environment.create(:production, [], '')
Puppet.initialize_settings

def print_ast(node, indentation = '')
  puts "#{indentation}#{node.class} #{node}"
  if node.respond_to? :each
    indentation += '  '
    node.each do |child|
      next unless child
      print_ast child, indentation
    end
  end
end

def yield_resources(node)
  if node.is_a? Puppet::Parser::AST::Resource
    yield node
  elsif node.respond_to? :each
    node.each do |child|
      if child
        yield_resources child do |grandchild|
          yield grandchild
        end
      end
    end
  end
end

def get_resources(node)
  resources = []
  yield_resources node do |r|
    resources << r
  end
  resources
end

def get_resource_stats(file)
  parser = Puppet::Parser::Parser.new $env
  parser.file = file
  ast = parser.parse
  resources = get_resources ast
  grouped = resources.group_by{|r| r.type}
  grouped.each {|type, resources| grouped[type] = resources.size}
  grouped
end

def merge_resource_stats(stat1, stat2)
  result = stat1.dup
  stat2.each do |type, count|
    result[type] = (result[type] || 0) + count
  end
  result
end

def get_spec_files(spec_dir)
  raise "#{spec_dir} is not a spec dir" unless spec_dir.end_with? '.spec'

  name = File.basename(spec_dir).gsub('.spec', '').split('-', 2).last
  name = name.gsub /-[0-9]+\.[0-9]+\.[0-9]+/, ''
  #name = pieces.drop(1).take(pieces.size - 2).join('-')

  manifestdir = File.join spec_dir, 'files', 'modules', name, 'manifests'
  Dir.glob File.join(manifestdir, '/**/*.pp')
end

def get_spec_resource_stats(spec_dir)
  files = get_spec_files spec_dir
  result = Hash.new

  files.each do |file|
    stats = get_resource_stats file
    result = merge_resource_stats result, stats
  end

  result
end

total_stats = Hash.new
spec_stats = Hash.new

specs = ARGV.empty? ? Dir.glob('*.spec') : ARGV
#specs = specs.take(10)

specs.each do |spec_dir|
  begin
    STDERR.puts spec_dir
    STDERR.flush

    stats = get_spec_resource_stats spec_dir
    total_stats = merge_resource_stats total_stats, stats

    spec_name = File.basename(spec_dir).gsub('.spec', '')
    spec_stats[spec_name] = stats
  rescue StandardError => e
    STDERR.puts "#{spec_dir} failed: #{e.message}"
    STDERR.flush
  end
end

total_stats = total_stats.sort_by{|(k, v)| -v}
sorted_types = total_stats.map{|(k,v)| k}

puts ";#{total_stats.map{|(k, v)| "#{k} (#{v})"}.join(';')}"
spec_stats.each do |name, stats|
  puts "#{name};#{sorted_types.map{|t| stats[t]}.join(';')}"
end