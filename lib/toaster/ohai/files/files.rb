

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/util/util"

provides "files"
files Mash.new

params = ENV["OHAI_PARAMS"]
if params["__read_from_file__"]
  params = File.read(params["__read_from_file__"])
end
params = JSON.parse(params)
params = params["files"] || {"paths" => []}

# build list of files
Toaster::Util.build_file_hash_for_ohai(params["paths"], files)
