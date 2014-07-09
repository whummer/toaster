# Load dependent gems into $LOAD_PATH and 
# invoke all necessary *require*s using Bundler

if !$toaster_bundler_loaded
  TOASTER_ROOT_DIR = File.join(File.dirname(__FILE__), "..","..","..")
  ENV['BUNDLE_GEMFILE'] = File.join(TOASTER_ROOT_DIR, "Gemfile")
  require 'rubygems'
  require 'bundler/setup'
  # bug fix for ruby 1.9+ required to load gem tidy
  require 'dl/import'
  DL::Importable = DL::Importer
  # call bundler
  Bundler.require(:default)
  $toaster_bundler_loaded = true
end
