

module Toaster

  #
  # Simple implementation of a map with thread-safe blocking operations:
  # - put(key, value): put a value to the map
  # - get(key): get a value from the map, do not remove value
  # - take(key): get a value from the map, remove value afterwards
  #
  # Author: Waldemar Hummer (hummer@dsg.tuwien.ac.at)
  #
  class BlockingMap

    def initialize()
      @hash = {}
      @semaphore = Mutex.new
      @signal = ConditionVariable.new
    end

    #
    # Put a value to the map, notifying waiting threads of new value
    #
    def put(key, value)
      @semaphore.synchronize do
        @hash[key] = value
        @signal.signal
      end
    end

    #
    # Get a value from the map. Blocks until a value with the given key becomes available.
    #
    def get(key)
      return do_get(key, false)
    end

    #
    # Get a value from the map. Blocks until a value with the given key becomes available.
    # This operation emoves the value from the map.
    #
    def take(key)
      return do_get(key, true)
    end

    private

    def do_get(key, delete = false)
      error_count = 0
      while true
        begin
          @semaphore.synchronize do
            # try to get immediately
            if @hash.include?(key)
              value = @hash[key]
              @hash.delete(key) if delete
              return value
            end
            # wait until new value has been added
            @signal.wait(@semaphore)
            # try to get again
            if @hash.include?(key)
              value = @hash[key]
              @hash.delete(key) if delete
              return value
            end
          end
        rescue Exception => ex
          puts "WARN: #{ex}\n#{ex.backtrace.join("\n")}"
          error_count += 1
          if error_count >= 5
            raise "Tried 5 times to get value from Toaster::BlockingMap, giving up..."
          end
          sleep(1)
        end
      end
    end

  end
end
