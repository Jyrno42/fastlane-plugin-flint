require_relative 'encrypt'
require_relative 'git_helper'
require_relative 'generator'

module Fastlane
  module Flint
    # These functions should only be used while in (UI.) interactive mode
    class ChangePassword
      def self.update(params: nil, from: nil, to: nil)
        ensure_ui_interactive
        from ||= ChangePassword.ask_password(message: "Old passphrase for Git Repo: ", confirm: false)
        to ||= ChangePassword.ask_password(message: "New passphrase for Git Repo: ", confirm: true)
        GitHelper.clear_changes
        encrypt = Encrypt.new
        workspace = GitHelper.clone(params[:git_url],
                                    params[:shallow_clone],
                                    manual_password: from,
                                    skip_docs: params[:skip_docs],
                                    branch: params[:git_branch],
                                    git_full_name: params[:git_full_name],
                                    git_user_email: params[:git_user_email],
                                    clone_branch_directly: params[:clone_branch_directly], 
                                    encrypt: encrypt)
        encrypt.clear_password(params[:git_url])
        encrypt.store_password(params[:git_url], to)

        if params[:app_identifier].kind_of?(Array)
          app_identifiers = params[:app_identifier]
        else
          app_identifiers = params[:app_identifier].to_s.split(/\s*,\s*/).uniq
        end
        app_identifier = app_identifiers[0].gsub! '.', '_'

        for cert_type in Flint.environments do
          alias_name = "%s-%s" % [app_identifier, cert_type]
          keystore_name = "%s.keystore" % alias_name
          Flint::Generator.update_keystore_password(workspace, keystore_name, alias_name, from, to)
        end

        message = "[fastlane] Changed passphrase"
        GitHelper.commit_changes(workspace, message, params[:git_url], params[:git_branch], nil, encrypt)
      end

      def self.ask_password(message: "Passphrase for Git Repo: ", confirm: true)
        ensure_ui_interactive
        loop do
          password = UI.password(message)
          if confirm
            password2 = UI.password("Type passphrase again: ")
            if password == password2
              return password
            end
          else
            return password
          end
          UI.error("Passphrases differ. Try again")
        end
      end

      def self.ensure_ui_interactive
        raise "This code should only run in interactive mode" unless UI.interactive?
      end

      private_class_method :ensure_ui_interactive
    end
  end
end
