class SettingsController < ApplicationController

  skip_before_action :verify_authenticity_token

  def configuration
  end

  def containers
  end
end
