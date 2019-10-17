require 'fastlane/action'
require_relative '../helper/flint_helper'
require_relative 'flint_action'

module Fastlane
    module Actions
      class FlintChangePasswordAction < FlintAction
        def self.run(params)
          params.load_configuration_file('Flintfile')

          FastlaneCore::PrintTable.print_values(config: params,
                                            hide_keys: [:workspace],
                                                title: "Summary for flint #{Fastlane::VERSION}")

          Flint::ChangePassword.update(params: params)
          UI.success("Successfully changed the password. Make sure to update the password on all your clients and servers")

        end
      end
    end
end
