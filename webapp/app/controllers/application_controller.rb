require "base_controller.rb"

class ApplicationController < BaseController
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery :with => :exception

  # global requires
  $LOAD_PATH << File.join(File.dirname(__FILE__), "../../../../../lib") 

  # use authentication based on "devise"
  #before_filter :authenticate_user!
  include Devise::Controllers::Helpers
  before_filter do
    fail "bad ancestor" unless self.kind_of?(Devise::Controllers::Helpers)
    fail "no mapping" unless Devise.class_variable_get(:@@mappings)[:user]
    authenticate_user!
  end

  #acts_as_token_authentication_handler_for User, :fallback_to_devise => false

end
