require File.expand_path('../boot', __FILE__)

root_dir = File.join(File.dirname(__FILE__), "..", "..")
$LOAD_PATH << File.join(root_dir, "lib")
# load dependencies using bundler
require "toaster/util/load_bundler"


require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.

# bug fix for ruby 1.9+
#require 'dl/import'
#DL::Importable = DL::Importer
#Bundler.require(:default, Rails.env)

module Toaster
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
  end
end
