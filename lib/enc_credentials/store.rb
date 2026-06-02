require "yaml"
require_relative "encryptor"
require_relative "key_resolver"
require_relative "credential_hash"

module EncCredentials
  # The primary interface for reading and writing an encrypted credentials file.
  #
  # Credentials are stored as YAML, encrypted with AES-256-GCM. Values are
  # accessible via method chaining, bracket notation, or +dig+.
  #
  # @example
  #   store = Store.new("credentials.yml.enc", key_path: "credentials.key")
  #   store.database.host       #=> "localhost"
  #   store[:api_key]           #=> "abc123"
  #   store.dig(:database, :password) #=> "secret"
  class Store
    DEFAULT_CREDENTIALS_FILE = "credentials.yml.enc"

    # @param credentials_path [String] path to the encrypted credentials file
    # @param key [String, nil] hex-encoded 32-byte key
    # @param key_path [String, nil] path to a file containing the hex key
    # @raise [EncCredentials::KeyError] if no key can be resolved
    def initialize(credentials_path = DEFAULT_CREDENTIALS_FILE, key: nil, key_path: nil)
      @credentials_path = credentials_path
      raw_key = KeyResolver.resolve(key: key, key_path: key_path)
      @encryptor = Encryptor.new(raw_key)
      @data = load_credentials
    end

    # @param key [Symbol, String]
    # @return [CredentialHash, Object, nil]
    def [](key)
      @data[key]
    end

    # @param keys [Array<Symbol, String>]
    # @return [CredentialHash, Object, nil]
    def dig(*keys)
      @data.dig(*keys)
    end

    # @param key [Symbol, String]
    # @return [Boolean]
    def key?(key)
      @data.key?(key)
    end

    # @return [Hash] the full credentials as a plain Ruby hash
    def to_h
      @data.to_h
    end

    def respond_to_missing?(name, include_private = false)
      @data.key?(name) || super
    end

    def method_missing(name, *args)
      return super unless @data.key?(name)
      @data[name]
    end

    # Encrypt +yaml_plaintext+ and overwrite the credentials file.
    #
    # @param yaml_plaintext [String] valid YAML content
    def write!(yaml_plaintext)
      encrypted = @encryptor.encrypt(yaml_plaintext)
      File.write(@credentials_path, encrypted)
    end

    # Decrypt and return the raw YAML string from the credentials file.
    #
    # @return [String] decrypted YAML, or an empty string if the file does not exist
    # @raise [DecryptionError] if the key is wrong or the file is corrupted
    def read_plaintext
      return "" unless File.exist?(@credentials_path)
      content = File.read(@credentials_path).strip
      return "" if content.empty?
      @encryptor.decrypt(content)
    end

    private

    def load_credentials
      plaintext = read_plaintext
      parsed = plaintext.empty? ? {} : YAML.safe_load(plaintext, symbolize_names: false)
      CredentialHash.new(parsed || {})
    end
  end
end
