require 'terminal-table'

require 'fastlane_core/print_table'

require_relative 'git_helper'
require_relative 'encrypt'

module Fastlane
  module Flint
    class Nuke
      attr_accessor :params
      attr_accessor :type

      attr_accessor :files

      def run(params, type: nil)
        self.params = params
        self.type = type

        params[:workspace] = GitHelper.clone(params[:git_url],
                                            params[:shallow_clone],
                                            skip_docs: params[:skip_docs],
                                            branch: params[:git_branch],
                                            git_full_name: params[:git_full_name],
                                            git_user_email: params[:git_user_email],
                                            clone_branch_directly: params[:clone_branch_directly],
                                            encrypt: Encrypt.configure(
                                              git_url: params[:git_url]
                                              ))

        had_app_identifier = self.params.fetch(:app_identifier, ask: false)
        self.params[:app_identifier] = '' # we don't really need a value here
        FastlaneCore::PrintTable.print_values(config: params,
                                          hide_keys: [:app_identifier, :workspace],
                                              title: "Summary for flint nuke #{Fastlane::VERSION}")

        prepare_list
        print_tables

        if params[:readonly]
          UI.user_error!("`fastlane flint nuke` doesn't delete anything when running with --readonly enabled")
        end

        if (self.files).count > 0
          unless params[:skip_confirmation]
            if type == "release"
              UI.confirm(
                "DANGER: By nuking release keys you might not " +
                "be able to update your app in the play store. Are you sure?"
              )
            end
            UI.error("---")
            UI.error("Are you sure you want to completely delete and revoke all the")
            UI.error("keystores listed above? (y/n)")
            UI.error("---")
          end
          if params[:skip_confirmation] || UI.confirm("Do you really want to nuke everything listed above?")
            nuke_it_now!
            UI.success("Successfully cleaned up ♻️")
          else
            UI.success("Cancelled nuking #thanks 🏠 👨 ‍👩 ‍👧")
          end
        else
          UI.success("No relevant keystores found, nothing to nuke here :)")
        end
      end

      # Collect all the keystores
      def prepare_list
        UI.message("Fetching keystores...")
        cert_type = Flint.cert_type_sym(type)

        certs = Dir[File.join(params[:workspace], "**", "*-#{cert_type.to_s}.keystore")]

        self.files = certs
      end

      # Print tables to ask the user
      def print_tables
        puts("")
        if self.files.count > 0
          rows = self.files.collect do |f|
            components = f.split(File::SEPARATOR)[-3..-1]
            file_type = components[0..1].reverse.join(" ")[0..-2]

            [file_type, components[2]]
          end
          puts(Terminal::Table.new({
            title: "Files that are going to be deleted".green,
            headings: ["Type", "File Name"],
            rows: rows
          }))
          puts("")
        end
      end

      def nuke_it_now!
        if self.files.count > 0
          delete_files!
        end

        # Now we need to commit and push all this too
        message = ["[fastlane]", "Nuked", "files", "for", type.to_s].join(" ")
        GitHelper.commit_changes(params[:workspace], message, self.params[:git_url], params[:git_branch], nil, Encrypt.configure(git_url: self.params[:git_url]))
      end

      private

      def delete_files!
        UI.header("Deleting #{self.files.count} files from the git repo...")

        self.files.each do |file|
          UI.message("Deleting file '#{File.basename(file)}'...")

          File.delete(file)
          UI.success("Successfully deleted file")
        end
      end
    end
  end
end
