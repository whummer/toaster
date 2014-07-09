# Load dependent gems into $LOAD_PATH and 
# invoke all necessary *require*s using Bundler

if !$toaster_bundler_loaded
  require 'rubygems'
  require 'bundler/setup'
  # bug fix for ruby 1.9+ required to load gem tidy
  require 'dl/import'
  DL::Importable = DL::Importer
  # call bundler
  Bundler.require(:default)
  $toaster_bundler_loaded = true
end
