require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/flint_helper'
require_relative '../helper/git_helper'
require_relative '../helper/encrypt'

module Fastlane
  module Actions
    class FlintAction < Action
      def self.description
        Flint::DESCRIPTION
      end

      def self.authors
        ['Jyrno Ader <jyrno@thorgate.eu>']
      end

      def self.details
        "Easily sync your keystores across your team using git"
      end

      def self.run(params)
        params.load_configuration_file('Flintfile')

        FastlaneCore::PrintTable.print_values(config: params,
                                          hide_keys: [:workspace],
                                              title: "Summary for flint #{Fastlane::VERSION}")

        encrypt = Flint::Encrypt.configure(
          git_url: params[:git_url]
        )
        params[:workspace] = Flint::GitHelper.clone(params[:git_url],
                                            params[:shallow_clone],
                                            skip_docs: params[:skip_docs],
                                            branch: params[:git_branch],
                                            git_full_name: params[:git_full_name],
                                            git_user_email: params[:git_user_email],
                                            clone_branch_directly: params[:clone_branch_directly],
                                            encrypt: encrypt)

        if params[:app_identifier].kind_of?(Array)
          app_identifiers = params[:app_identifier]
        else
          app_identifiers = params[:app_identifier].to_s.split(/\s*,\s*/).uniq
        end

        # sometimes we get an array with arrays, this is a bug. To unblock people using flint, I suggest we flatten!
        # then in the future address the root cause of https://github.com/fastlane/fastlane/issues/11324
        app_identifiers.flatten!

        # Keystore
        password = encrypt.password
        keystore_name, files_to_commmit = fetch_keystore(params: params, app_identifier: app_identifiers[0], password: password)

        # Done
        if files_to_commmit.count > 0 && !params[:readonly]
          message = Flint::GitHelper.generate_commit_message(params)
          Flint::GitHelper.commit_changes(params[:workspace], message, params[:git_url], params[:git_branch], files_to_commmit, encrypt)
        end

        # Print a summary table for each app_identifier
        app_identifiers.each do |app_identifier|
          Flint::TablePrinter.print_summary(app_identifier: app_identifier, type: params[:type], keystore_name: keystore_name)
        end

        UI.success("All required keystores are installed 🙌".green)
      ensure
        Flint::GitHelper.clear_changes
      end

      def self.fetch_keystore(params: nil, app_identifier: nil, password: nil)
        cert_type = Flint.cert_type_sym(params[:type])
        files_to_commmit = []

        app_identifier = app_identifier.gsub! '.', '_'

        alias_name = "%s-%s" % [app_identifier, cert_type.to_s]

        keystore_name = "%s.keystore" % [alias_name]
        target_path = File.join(params[:target_dir], keystore_name)

        certs = Dir[File.join(params[:workspace], "certs", keystore_name)]

        if certs.count == 0
          UI.important("Couldn't find a valid keystore in the git repo for #{cert_type}... creating one for you now")
          UI.crash!("No code signing keystore found and can not create a new one because you enabled `readonly`") if params[:readonly]
          cert_path = Flint::Generator.generate_keystore(params, keystore_name, alias_name, password)
          files_to_commmit << cert_path

          # install and activate the keystore
          UI.verbose("Installing keystore '#{keystore_name}'")
          Flint::Utils.import(cert_path, target_path, keystore_name, alias_name, password)
          Flint::Utils.activate(keystore_name, alias_name, password, params[:keystore_properties_path])
        else
          cert_path = certs.last
          UI.message("Installing keystore...")

          if Flint::Utils.installed?(cert_path, target_path)
            UI.verbose("Keystore '#{File.basename(cert_path)}' is already installed on this machine")
          else
            UI.verbose("Installing keystore '#{keystore_name}'")
            Flint::Utils.import(cert_path, target_path, keystore_name, alias_name, password)
          end

          # Print keystore info
          puts("")
          puts(Flint::Utils.get_keystore_info(cert_path, password))
          puts("")

          # Activate the cert
          Flint::Utils.activate(keystore_name, alias_name, password, params[:keystore_properties_path])
        end

        return File.basename(cert_path).gsub(".keystore", ""), files_to_commmit
      end

      def self.available_options
        user = CredentialsManager::AppfileConfig.try_fetch_value(:apple_dev_portal_id)
        user ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)

        [
          FastlaneCore::ConfigItem.new(key: :git_url,
                                      env_name: "FLINT_GIT_URL",
                                      description: "URL to the git repo containing all the keystores",
                                      optional: false,
                                      short_option: "-r"),
          FastlaneCore::ConfigItem.new(key: :full_name,
                                      env_name: "FLINT_FULL_NAME",
                                      description: "Full name of the owner of the keystores",
                                      optional: false,
                                      is_string: true,
                                      short_option: "-n"),
          FastlaneCore::ConfigItem.new(key: :orgization,
                                      env_name: "FLINT_ORGANIZATION",
                                      description: "Organization of the owner of the keystores",
                                      is_string: true,
                                      short_option: "-o",
                                      default_value: ""),
          FastlaneCore::ConfigItem.new(key: :orgization_unit,
                                      env_name: "FLINT_ORGANIZATION_UNIT",
                                      description: "Organization unit of the owner of the keystores",
                                      is_string: true,
                                      short_option: "-u",
                                      default_value: ""),
          FastlaneCore::ConfigItem.new(key: :city,
                                      env_name: "FLINT_CITY",
                                      description: "City of the owner of the keystores",
                                      optional: false,
                                      is_string: true,
                                      short_option: "-c"),
          FastlaneCore::ConfigItem.new(key: :state,
                                      env_name: "FLINT_STATE",
                                      description: "State of the owner of the keystores",
                                      optional: false,
                                      is_string: true,
                                      short_option: "-s"),
          FastlaneCore::ConfigItem.new(key: :country,
                                      env_name: "FLINT_COUNTRY",
                                      description: "Country of the owner of the keystores (2 letters, e.g EE)",
                                      optional: false,
                                      is_string: true,
                                      short_option: "-x"),
          FastlaneCore::ConfigItem.new(key: :git_branch,
                                      env_name: "FLINT_GIT_BRANCH",
                                      description: "Specific git branch to use",
                                      default_value: 'master'),
          FastlaneCore::ConfigItem.new(key: :type,
                                      env_name: "FLINT_TYPE",
                                      description: "Define the profile type, can be #{Flint.environments.join(', ')}",
                                      is_string: true,
                                      short_option: "-y",
                                      default_value: 'development',
                                      verify_block: proc do |value|
                                        unless Flint.environments.include?(value)
                                          UI.user_error!("Unsupported environment #{value}, must be in #{Flint.environments.join(', ')}")
                                        end
                                      end),
          FastlaneCore::ConfigItem.new(key: :app_identifier,
                                      short_option: "-a",
                                      env_name: "FLINT_APP_IDENTIFIER",
                                      description: "The bundle identifier(s) of your app (comma-separated)",
                                      is_string: false,
                                      type: Array, # we actually allow String and Array here
                                      skip_type_validation: true,
                                      code_gen_sensitive: true,
                                      default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier),
                                      default_value_dynamic: true),
          FastlaneCore::ConfigItem.new(key: :readonly,
                                      env_name: "FLINT_READONLY",
                                      description: "Only fetch existing keystores, don't generate new ones",
                                      is_string: false,
                                      default_value: false),
          FastlaneCore::ConfigItem.new(key: :git_full_name,
                                      env_name: "FLINT_GIT_FULL_NAME",
                                      description: "git user full name to commit",
                                      optional: true,
                                      default_value: nil),
          FastlaneCore::ConfigItem.new(key: :git_user_email,
                                      env_name: "FLINT_GIT_USER_EMAIL",
                                      description: "git user email to commit",
                                      optional: true,
                                      default_value: nil),
          FastlaneCore::ConfigItem.new(key: :verbose,
                                      env_name: "FLINT_VERBOSE",
                                      description: "Print out extra information and all commands",
                                      is_string: false,
                                      default_value: false,
                                      verify_block: proc do |value|
                                        FastlaneCore::Globals.verbose = true if value
                                      end),
          FastlaneCore::ConfigItem.new(key: :keystore_properties_path,
                                      env_name: "FLINT_KEYSTORE_PROPERTIES_PATH",
                                      description: "Set target path for keystore.properties fie",
                                      default_value: "../keystore.properties"),
          FastlaneCore::ConfigItem.new(key: :target_dir,
                                      env_name: "FLINT_TARGET_DIR",
                                      description: "Set target dir for flint keystores",
                                      default_value: "../app/"),
          FastlaneCore::ConfigItem.new(key: :skip_confirmation,
                                      env_name: "FLINT_SKIP_CONFIRMATION",
                                      description: "Disables confirmation prompts during nuke, answering them with yes",
                                      is_string: false,
                                      default_value: false),
          FastlaneCore::ConfigItem.new(key: :shallow_clone,
                                      env_name: "FLINT_SHALLOW_CLONE",
                                      description: "Make a shallow clone of the repository (truncate the history to 1 revision)",
                                      is_string: false,
                                      default_value: false),
          FastlaneCore::ConfigItem.new(key: :clone_branch_directly,
                                      env_name: "FLINT_CLONE_BRANCH_DIRECTLY",
                                      description: "Clone just the branch specified, instead of the whole repo. This requires that the branch already exists. Otherwise the command will fail",
                                      is_string: false,
                                      default_value: false),
          FastlaneCore::ConfigItem.new(key: :workspace,
                                      description: nil,
                                      verify_block: proc do |value|
                                        unless Helper.test?
                                          if value.start_with?("/var/folders") || value.include?("tmp/") || value.include?("temp/")
                                            # that's fine
                                          else
                                            UI.user_error!("Specify the `git_url` instead of the `path`")
                                          end
                                        end
                                      end,
                                      optional: true),
          FastlaneCore::ConfigItem.new(key: :skip_docs,
                                      env_name: "FLINT_SKIP_DOCS",
                                      description: "Skip generation of a README.md for the created git repository",
                                      is_string: false,
                                      default_value: false)
        ]
      end

      def self.is_supported?(platform)
        # Adjust this if your plugin only works for a particular platform (iOS vs. Android, for example)
        # See: https://docs.fastlane.tools/advanced/#control-configuration-by-lane-and-by-platform
        #
        # [:ios, :mac, :android].include?(platform)
        true
      end
    end
  end
end
