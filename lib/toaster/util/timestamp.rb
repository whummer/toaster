

#
# Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
#

require 'toaster/util/config'

include Toaster

module Toaster

  #
  # Class that keeps track of timestamps, computes durations, etc.
  # The implementation is *not* thread-safe.
  #
  class TimeStamp

    @@timestamps = {}
    @@output = true
    @@listeners = []
    @@mutex = Mutex.new

    class << self;
      attr_accessor :TIME_SERVICE_URL
    end
    @TIME_SERVICE_URL = ::Toaster::Config.get("testing.timeservice_url")

    def self.add(time=nil, key="__default__")
      previous = nil
      @@mutex.synchronize do
        time = TimeStamp.now() if !time
        time = time.to_f
        @@timestamps[key] = [] if !@@timestamps[key]
        previous = @@timestamps[key].empty? ? nil : @@timestamps[key][-1]
        @@timestamps[key] << time
        #puts "INFO: Adding timestamp #{time} for key '#{key}'"
      end
      notify(key, time, previous)
    end

    #
    # Returns the current time in seconds since the Epoch, with float precision.
    #  
    # This method accesses a small "time service" on another host.
    # The reason why we need this is that we have experienced some of
    # the LXC containers (which get spawned on the testing host) actually
    # change the host's system time..(!) So, if we are simply measuring 
    # the local system time on the test host, our time measurements 
    # result in bogus data.
    #
    def self.now(retries = 2)
      (0..retries).each do |i|
        out = `curl -s "#{TimeStamp.TIME_SERVICE_URL}" 2> /dev/null`
        out = out.strip
        if out.match(/^[0-9\.]+$/)
          return out.to_i
        else
          sleep 0.5
          # run next attempt in next iteration
        end
      end
      # fallback, if the time service is unavailable...
      puts "WARN: Time service not available (#{retries + 1} attempts), URL: '#{TimeStamp.TIME_SERVICE_URL}'"
      return Time.new.to_f
    end

    def self.do_output(output)
      @@output = output
    end

    def self.print(action="n/a", format=nil, key="__default__", &block)
      format = "Duration for '%s': %d seconds (%.3f ms)\n" if !format
      diff = 0
      t1 = 0
      t2 = 0
      @@mutex.synchronize do
        t1 = @@timestamps[key][-2]
        t2 = @@timestamps[key][-1]
        diff = t2 - t1
      end
      if @@output
        do_print = true
        if block
          do_print = block.call(diff, t1, t2)
        end
        if do_print
          printf(format, action, diff.to_f.round, diff) 
        end
      end
    end

    def self.add_and_print(action="n/a", format=nil, key="__default__", &block)
      add(nil, key)
      print(action, format, key, &block)
    end

    def self.add_listener(l)
      @@mutex.synchronize do
        @@listeners << l
      end
    end

    def self.clear_listeners()
      @@mutex.synchronize do
        @@listeners.clear()
      end
    end

    def self.notify(key, stamp, previous_stamp)
      keys_to_remove = Set.new
      l_copy = []
      @@mutex.synchronize do
        l_copy = @@listeners.dup
      end
      l_copy.each do |l|
        removes = l.notify(key, stamp, previous_stamp)
        removes = Set.new if !removes || !removes.respond_to?("each")
        removes.each do |r|
          keys_to_remove << r
        end
      end
      @@mutex.synchronize do
        keys_to_remove.each do |k|
          @@timestamps.delete(k)
        end
      end
    end

  end
end
