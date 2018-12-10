require 'fastlane_core/command_executor'

require_relative 'change_password'
require_relative 'encrypt'

module Fastlane
  module Flint
    class GitHelper
      FLINT_VERSION_FILE_NAME = "flint_version.txt"

      def self.clone(git_url,
                    shallow_clone,
                    manual_password: nil,
                    skip_docs: false,
                    branch: "master",
                    git_full_name: nil,
                    git_user_email: nil,
                    clone_branch_directly: false,
                    encrypt: nil)
        # Note: if you modify the parameters above, don't forget to also update the method call in
        # - flint_action.rb
        # - nuke.rb
        # - change_password.rb
        # - commands_generator.rb
        #
        return @dir if @dir

        @dir = Dir.mktmpdir

        command = "git clone '#{git_url}' '#{@dir}'"
        if shallow_clone
          command << " --depth 1 --no-single-branch"
        elsif clone_branch_directly
          command += " -b #{branch.shellescape} --single-branch"
        end

        UI.message("Cloning remote git repo...")

        if branch && !clone_branch_directly
          UI.message("If cloning the repo takes too long, you can use the `clone_branch_directly` option in flint.")
        end

        begin
          # GIT_TERMINAL_PROMPT will fail the `git clone` command if user credentials are missing
          FastlaneCore::CommandExecutor.execute(command: "GIT_TERMINAL_PROMPT=0 #{command}",
                                              print_all: FastlaneCore::Globals.verbose?,
                                          print_command: FastlaneCore::Globals.verbose?)
        rescue
          UI.error("Error cloning keystores repo, please make sure you have read access to the repository you want to use")
          if branch && clone_branch_directly
            UI.error("You passed '#{branch}' as branch in combination with the `clone_branch_directly` flag. Please remove `clone_branch_directly` flag on the first run for _flint_ to create the branch.")
          end
          UI.error("Run the following command manually to make sure you're properly authenticated:")
          UI.command(command)
          UI.user_error!("Error cloning keystores git repo, please make sure you have access to the repository - see instructions above")
        end

        add_user_config(git_full_name, git_user_email)

        UI.user_error!("Error cloning repo, make sure you have access to it '#{git_url}'") unless File.directory?(@dir)

        checkout_branch(branch) unless branch == "master"

        if !Helper.test? && GitHelper.flint_version(@dir).nil? && manual_password.nil? && File.exist?(File.join(@dir, "README.md"))
          UI.important("Migrating to new flint...")
          ChangePassword.update(params: { git_url: git_url,
                                      git_branch: branch,
                                  shallow_clone: shallow_clone },
                                            from: "",
                                              to: encrypt.password(git_url))
          return self.clone(git_url, shallow_clone)
        end

        encrypt.decrypt_repo(path: @dir, git_url: git_url, manual_password: manual_password)

        return @dir
      end

      def self.generate_commit_message(params)
        # 'Automatic commit via fastlane'
        [
          "[fastlane]",
          "Updated",
          params[:type].to_s,
          "and platform android"
        ].join(" ")
      end

      def self.flint_version(workspace)
        path = File.join(workspace, FLINT_VERSION_FILE_NAME)
        if File.exist?(path)
          Gem::Version.new(File.read(path))
        end
      end

      def self.commit_changes(path, message, git_url, branch = "master", files_to_commmit = nil, encrypt = nil)
        files_to_commmit ||= []
        Dir.chdir(path) do
          return if `git status`.include?("nothing to commit")

          encrypt.encrypt_repo(path: path, git_url: git_url)
          commands = []

          if files_to_commmit.count > 0 # e.g. for nuke this is treated differently
            if !File.exist?(FLINT_VERSION_FILE_NAME) || File.read(FLINT_VERSION_FILE_NAME) != Fastlane::VERSION.to_s
              files_to_commmit << FLINT_VERSION_FILE_NAME
              File.write(FLINT_VERSION_FILE_NAME, Fastlane::VERSION) # stored unencrypted
            end

            template = File.read("#{Flint::ROOT}/assets/READMETemplate.md")
            readme_path = "README.md"
            if !File.exist?(readme_path) || File.read(readme_path) != template
              files_to_commmit << readme_path
              File.write(readme_path, template)
            end

            # `git add` each file we want to commit
            #   - Fixes https://github.com/fastlane/fastlane/issues/8917
            #   - Fixes https://github.com/fastlane/fastlane/issues/8793
            #   - Replaces, closes and fixes https://github.com/fastlane/fastlane/pull/8919
            commands += files_to_commmit.map do |current_file|
              "git add #{current_file.shellescape}"
            end
          else
            # No specific list given, e.g. this happens on `fastlane flint nuke`
            # We just want to run `git add -A` to commit everything
            commands << "git add -A"
          end
          commands << "git commit -m #{message.shellescape}"
          commands << "GIT_TERMINAL_PROMPT=0 git push origin #{branch.shellescape}"

          UI.message("Pushing changes to remote git repo...")

          commands.each do |command|
            FastlaneCore::CommandExecutor.execute(command: command,
                                                print_all: FastlaneCore::Globals.verbose?,
                                            print_command: FastlaneCore::Globals.verbose?)
          end
        end
        FileUtils.rm_rf(path)
        @dir = nil
      rescue => ex
        UI.error("Couldn't commit or push changes back to git...")
        UI.error(ex)
      end

      def self.clear_changes
        return unless @dir

        FileUtils.rm_rf(@dir)
        @dir = nil
      end

      # Create and checkout an specific branch in the git repo
      def self.checkout_branch(branch)
        return unless @dir

        commands = []
        if branch_exists?(branch)
          # Checkout the branch if it already exists
          commands << "git checkout #{branch.shellescape}"
        else
          # If a new branch is being created, we create it as an 'orphan' to not inherit changes from the master branch.
          commands << "git checkout --orphan #{branch.shellescape}"
          # We also need to reset the working directory to not transfer any uncommitted changes to the new branch.
          commands << "git reset --hard"
        end

        UI.message("Checking out branch #{branch}...")

        Dir.chdir(@dir) do
          commands.each do |command|
            FastlaneCore::CommandExecutor.execute(command: command,
                                                  print_all: FastlaneCore::Globals.verbose?,
                                                  print_command: FastlaneCore::Globals.verbose?)
          end
        end
      end

      # Checks if a specific branch exists in the git repo
      def self.branch_exists?(branch)
        return unless @dir

        result = Dir.chdir(@dir) do
          FastlaneCore::CommandExecutor.execute(command: "git --no-pager branch --list origin/#{branch.shellescape} --no-color -r",
                                                print_all: FastlaneCore::Globals.verbose?,
                                                print_command: FastlaneCore::Globals.verbose?)
        end
        return !result.empty?
      end

      def self.add_user_config(user_name, user_email)
        # Add git config if needed
        commands = []
        commands << "git config user.name \"#{user_name}\"" unless user_name.nil?
        commands << "git config user.email \"#{user_email}\"" unless user_email.nil?

        return if commands.empty?

        UI.message("Add git user config to local git repo...")
        Dir.chdir(@dir) do
          commands.each do |command|
            FastlaneCore::CommandExecutor.execute(command: command,
                                                  print_all: FastlaneCore::Globals.verbose?,
                                                  print_command: FastlaneCore::Globals.verbose?)
          end
        end
      end
    end
  end
end
