
#
# Author:: Anthony Goddard <agoddard@mbl.edu>
# Copyright:: Copyright (c) 2011 Marine Biological Laboratory.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
# original netstat code courtesy of Krzysztof Wilczynski http://snippets.dzone.com/tag/netstat 
#
#


@protocols = ["tcp","udp"]

tcp_states = {
  '00' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
  'FF' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
  '01' => 'ESTABLISHED',
  '02' => 'SYN_SENT',
  '03' => 'SYN_RECV',
  '04' => 'FIN_WAIT1',
  '05' => 'FIN_WAIT2',
  '06' => 'TIME_WAIT',
  '07' => 'CLOSE',
  '08' => 'CLOSE_WAIT',
  '09' => 'LAST_ACK',
  '0A' => 'LISTEN',
  '0B' => 'CLOSING'
}

single_entry_pattern = Regexp.new(
  /^\s*\d+:\s+(.{8}):(.{4})\s+(.{8}):(.{4})\s+(.{2})/
)


@listening = {}
@protocols.each do |protocol|
   @listening[protocol.to_sym] = []
  File.open('/proc/net/' + protocol).each do |i|
    i = i.strip
    if match = i.match(single_entry_pattern)
      local_IP = match[1].to_i(16)
      local_IP = [local_IP].pack("N").unpack("C4").reverse.join('.')
      local_port = match[2].to_i(16)
      remote_IP = match[3].to_i(16)
      remote_IP = [remote_IP].pack("N").unpack("C4").reverse.join('.')
      remote_port = match[4].to_i(16)
      connection_state = match[5]
      connection_state = tcp_states[connection_state]
      @listening[protocol.to_sym] << {local_IP => local_port}

    end
  end
end


provides 'network/ports'

ports = Mash.new

@protocols.each do |protocol|
  ports[protocol.to_sym] = []
  @listening[protocol.to_sym].each do |port|
    ports[protocol.to_sym] << port
  end
end

network[:ports] = Mash.new
network[:ports] = ports
