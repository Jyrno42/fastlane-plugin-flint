require 'fastlane/action'
require_relative '../helper/git_helper'
require_relative '../helper/encrypt'

module Fastlane
    module Actions
      class FlintSetupAction < FlintAction
        def self.run(params)
            containing = FastlaneCore::Helper.fastlane_enabled_folder_path
            path = File.join(containing, "Flintfile")
  
            if File.exist?(path)
              FastlaneCore::UI.user_error!("You already have a Flintfile in this directory (#{path})")
              return 0
            end
    
            template = File.read("#{Flint::ROOT}/assets/FlintfileTemplate")
      
            UI.important("Please create a new, private git repository")
            UI.important("to store the keystores there")

            url = UI.input("URL of the Git Repo: ")
      
            template.gsub!("[[GIT_URL]]", url)
            File.write(path, template)
            UI.success("Successfully created '#{path}'. You can open the file using a code editor.")
      
            UI.important("Please mopdify build.gradle file (usually under app/build.gradle):")
            UI.message("Add before `android {` line:")
            UI.message("    // Load keystore")
            UI.message("    def keystorePropertiesFile = rootProject.file(\"keystore.properties\");")
            UI.message("    def keystoreProperties = new Properties()")
            UI.message("    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))")
            UI.message("Add after the closing bracket for `defaultConfig {`:")
            UI.message("    signingConfigs {")
            UI.message("        development {")
            UI.message("            storeFile file(keystoreProperties['storeFile'])")
            UI.message("            storePassword keystoreProperties['storePassword']")
            UI.message("            keyAlias keystoreProperties['keyAlias']")
            UI.message("            keyPassword keystoreProperties['keyPassword']")
            UI.message("       }")
            UI.message("        release {")
            UI.message("            storeFile file(keystoreProperties['storeFile'])")
            UI.message("            storePassword keystoreProperties['storePassword']")
            UI.message("            keyAlias keystoreProperties['keyAlias']")
            UI.message("            keyPassword keystoreProperties['keyPassword']")
            UI.message("       }")
            UI.message("    }")
            UI.important("This will load the appropriate keystore during release builds")
      
            UI.important("You can now run `fastlane flint type:development` and `fastlane flint type:release`")
            UI.message("On the first run for each environment it will create the keystore for you.")
            UI.message("From then on, it will automatically import the existing keystores.")
            UI.message("For more information visit https://docs.fastlane.tools/actions/flint/")

        end
      end
    end
end
