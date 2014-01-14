
require 'logger'

module Toaster 
  @@logger = Logger.new(STDOUT)
  @@logger.level = Logger::DEBUG

  module Logging 

    def self.level(log_level)
      @@logger.level = log_level  
    end
    
    def self.get_level 
      @@logger.level
    end
    
  end
end
