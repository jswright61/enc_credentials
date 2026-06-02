require_relative "enc_credentials/version"
require_relative "enc_credentials/encryptor"
require_relative "enc_credentials/key_resolver"
require_relative "enc_credentials/credential_hash"
require_relative "enc_credentials/store"

# Symmetrically encrypted credential store using AES-256-GCM, inspired by
# Rails encrypted credentials.
#
# @example
#   store = EncCredentials.load("credentials.yml.enc", key_path: "credentials.key")
#   store.database.password   #=> "secret"
#   store[:api_key]           #=> "abc123"
module EncCredentials
  # Raised when decryption fails due to a wrong key or corrupted file.
  DecryptionError = Class.new(StandardError)

  # Raised when no encryption key can be found via any resolution path.
  KeyError = Class.new(StandardError)

  # Load and decrypt a credentials file, returning a {Store}.
  #
  # Key resolution order:
  # 1. +key:+ keyword argument
  # 2. File at +key_path:+ (defaults to +credentials.key+)
  # 3. +ENC_CREDENTIALS_KEY+ environment variable
  #
  # @param credentials_path [String] path to the encrypted file
  # @param key [String, nil] hex-encoded 32-byte key
  # @param key_path [String, nil] path to a file containing the hex key
  # @return [Store]
  def self.load(credentials_path = Store::DEFAULT_CREDENTIALS_FILE, key: nil, key_path: nil)
    Store.new(credentials_path, key: key, key_path: key_path)
  end
end
