require 'terminal-table'

require 'fastlane_core/print_table'

require_relative 'utils'

module Fastlane
  module Flint
    class TablePrinter
      def self.print_summary(app_identifier: nil, type: nil, platform: :android, keystore_name: nil)
        rows = []

        type = type.to_sym

        rows << ["App Identifier", "", app_identifier]
        rows << ["Type", "", type]
        rows << ["Platform", "", platform.to_s]
        rows << ["Keystore", "", keystore_name]

        params = {}
        params[:rows] = FastlaneCore::PrintTable.transform_output(rows)
        params[:title] = "Installed Keystores".green
        params[:headings] = ['Parameter', 'Environment Variable', 'Value']

        puts("")
        puts(Terminal::Table.new(params))
        puts("")
      end
    end
  end
end
