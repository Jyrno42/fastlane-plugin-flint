require_relative 'change_password'

module Fastlane
  module Flint
    class Encrypt
      require 'base64'
      require 'openssl'
      require 'securerandom'
      require 'shellwords'

      def initialize()
        # Keep the password in the memory so we can reuse it later on
        @tmp_password = nil
      end

      def server_name(git_url)
        ["flint", git_url].join("_")
      end

      def password(git_url)
        password = ENV["FLINT_PASSWORD"]
        unless password
          if @tmp_password
            password = @tmp_password
          end
        end

        unless password && password != ''
          if !UI.interactive?
            UI.error("The FLINT_PASSWORD environment variable did not contain a password.")
            UI.error("Bailing out instead of asking for a password, since this is non-interactive mode.")
            UI.user_error!("Try setting the FLINT_PASSWORD environment variable, or temporarily enable interactive mode to store a password.")
          else
            UI.important("Enter the passphrase that should be used to encrypt/decrypt your keystores")
            UI.important("Make sure to remember the password, as you'll need it when you run flint again")
            password = ChangePassword.ask_password(confirm: true)
            store_password(git_url, password)
          end
        end

        return password
      end

      def store_password(git_url, password)
        @tmp_password = password
      end

      def clear_password(git_url)
        @tmp_password = ""
      end

      def encrypt_repo(path: nil, git_url: nil)
        iterate(path) do |current|
          encrypt(path: current,
            password: password(git_url))
          UI.success("🔒  Encrypted '#{File.basename(current)}'") if FastlaneCore::Globals.verbose?
        end
        UI.success("🔒  Successfully encrypted keystores repo")
      end

      def decrypt_repo(path: nil, git_url: nil, manual_password: nil)
        iterate(path) do |current|
          begin
            decrypt(path: current,
              password: manual_password || password(git_url))
          rescue
            UI.error("Couldn't decrypt the repo, please make sure you enter the right password! %s" % manual_password || password(git_url))
            UI.user_error!("Invalid password passed via 'FLINT_PASSWORD'") if ENV["FLINT_PASSWORD"]
            clear_password(git_url)
            password(git_url)
            decrypt_repo(path: path, git_url: git_url)
            return
          end
          UI.success("🔓  Decrypted '#{File.basename(current)}'") if FastlaneCore::Globals.verbose?
        end
        UI.success("🔓  Successfully decrypted keystores repo")
      end

      private

      def iterate(source_path)
        Dir[File.join(source_path, "**", "*.{keystore}")].each do |path|
          next if File.directory?(path)
          yield(path)
        end
      end

      # We encrypt with MD5 because that was the most common default value in older fastlane versions which used the local OpenSSL installation
      # A more secure key and IV generation is needed in the future
      # IV should be randomly generated and provided unencrypted
      # salt should be randomly generated and provided unencrypted (like in the current implementation)
      # key should be generated with OpenSSL::KDF::pbkdf2_hmac with properly chosen parameters
      # Short explanation about salt and IV: https://stackoverflow.com/a/1950674/6324550
      def encrypt(path: nil, password: nil)
        UI.user_error!("No password supplied") if password.to_s.strip.length == 0

        data_to_encrypt = File.read(path)
        salt = SecureRandom.random_bytes(8)

        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.encrypt
        cipher.pkcs5_keyivgen(password, salt, 1, "MD5")
        encrypted_data = "Salted__" + salt + cipher.update(data_to_encrypt) + cipher.final

        File.write(path, Base64.encode64(encrypted_data))
      rescue FastlaneCore::Interface::FastlaneError
        raise
      rescue => error
        UI.error(error.to_s)
        UI.crash!("Error encrypting '#{path}'")
      end

      # The encryption parameters in this implementations reflect the old behaviour which depended on the users' local OpenSSL version
      # 1.0.x OpenSSL and earlier versions use MD5, 1.1.0c and newer uses SHA256, we try both before giving an error
      def decrypt(path: nil, password: nil, hash_algorithm: "MD5")
        stored_data = Base64.decode64(File.read(path))
        salt = stored_data[8..15]
        data_to_decrypt = stored_data[16..-1]

        decipher = OpenSSL::Cipher.new('AES-256-CBC')
        decipher.decrypt
        decipher.pkcs5_keyivgen(password, salt, 1, hash_algorithm)

        decrypted_data = decipher.update(data_to_decrypt) + decipher.final

        File.binwrite(path, decrypted_data)
      rescue => error
        fallback_hash_algorithm = "SHA256"
        if hash_algorithm != fallback_hash_algorithm
          decrypt(path, password, fallback_hash_algorithm)
        else
          UI.error(error.to_s)
          UI.crash!("Error decrypting '#{path}'")
        end
      end
    end
  end
end
