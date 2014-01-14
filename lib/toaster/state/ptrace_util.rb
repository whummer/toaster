
#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require "toaster/state/transition_edge"
require "toaster/markup/markup_util"

include Toaster

module Toaster

  class PtraceUtil

    WORD_SIZE = 8

    def self.read_string(ptrace_target, addr)
      str = ""
      do_continue = true
      iter = 0
      while do_continue
        v = ptrace_target.text.peek(addr + (WORD_SIZE * iter))
        (0..7).each do |shift_bytes|
          shift = 8 * shift_bytes
          byte = (v >> shift) & 0xFF
          if byte == 0
            #puts "END OF STRING!!"
            do_continue = false
            break
          end
          str += byte.chr
        end
        iter += 1
      end
      return str
    end

    def self.get_filename_for_fd(pid, fd)
      path = "/proc/#{pid}/fd/#{fd}"
      begin
        return File.readlink(path)
      rescue
        return nil
      end
    end

  end
end
