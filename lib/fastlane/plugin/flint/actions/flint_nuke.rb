require 'fastlane/action'
require_relative '../helper/flint_helper'
require_relative 'flint_action'

module Fastlane
    module Actions
      class FlintNukeAction < FlintAction
        def self.run(params)
          params.load_configuration_file('Flintfile')

          Flint::Nuke.new.run(params, type: 'development')
          Flint::Nuke.new.run(params, type: 'release')
        end
      end
    end
end
