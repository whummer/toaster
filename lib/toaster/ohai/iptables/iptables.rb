
################################################################################
# (c) Waldemar Hummer
################################################################################

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/util/util"

provides "iptables"
files Mash.new

params = ENV["OHAI_PARAMS"]
if params["__read_from_file__"]
  params = File.read(params["__read_from_file__"])
end
params = JSON.parse(params)
params = params["files"] || {"paths" => []}

# build list of files
params["paths"].each do |path|
  if File.exist?(path)
    fileObj = File.new(path)
    statObj = File::Stat.new(path)
    files[path] = {
      "mode" => statObj.mode,
      "bytes" => fileObj.size,
      "owner" => "#{statObj.uid}:#{statObj.gid}"
    }
    if File.directory?(path)
      entries = Dir.entries(path).size - 2
      entries = 0 if entries < 0
      entries_rec = -1
      if path != "" && !path.match(/\/+((dev)|(etc)|(lib)|(lib32)|(lib64)|(proc)|(opt)|(run)|(sys)|(usr)|(var))\/*/)
        # find number of descendants (recursively)
        entries_rec = `find /tmp/ | wc -l`
      end
      files[path]["type"] = "dir"
      files[path]["num_entries"] = entries
      files[path]["entries_recursive"] = entries_rec
    else
      md5 = Toaster::Util.file_md5(path)
      files[path]["hash"] = md5.strip if md5
    end
  end
end
