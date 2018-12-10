require 'fastlane_core/helper'
require 'fastlane/plugin/flint/version'

module Fastlane
  module Flint
    Helper = FastlaneCore::Helper # you gotta love Ruby: Helper.* should use the Helper class contained in FastlaneCore
    UI = FastlaneCore::UI
    ROOT = Pathname.new(File.expand_path('../../..', __FILE__))
    DESCRIPTION = "Easily sync your keystores across your team using git"

    # Return all .rb files inside the "actions" and "helper" directory
    def self.all_classes
      Dir[File.expand_path('**/{actions,helper}/*.rb', File.dirname(__FILE__))]
    end

    def self.environments
      return %w(development release)
    end
  
    def self.cert_type_sym(type)
      return :development if type == "development"
      return :release if type == "release"
      raise "Unknown cert type: '#{type}'"
    end
  end
end

# By default we want to import all available actions and helpers
# A plugin can contain any number of actions and plugins
Fastlane::Flint.all_classes.each do |current|
  require current
end
