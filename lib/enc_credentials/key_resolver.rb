module EncCredentials
  # Resolves the encryption key from one of three sources, in priority order:
  # 1. A +key:+ value passed directly
  # 2. A key file (defaults to +credentials.key+ in the working directory)
  # 3. The +ENC_CREDENTIALS_KEY+ environment variable
  module KeyResolver
    DEFAULT_KEY_FILE = "credentials.key"
    ENV_VAR = "ENC_CREDENTIALS_KEY"

    # Resolve the hex key string from available sources.
    #
    # @param key [String, nil] hex key passed directly
    # @param key_path [String, nil] path to a key file; falls back to {DEFAULT_KEY_FILE}
    # @return [String] hex-encoded key
    # @raise [EncCredentials::KeyError] if no key can be found
    def self.resolve(key: nil, key_path: nil)
      return key.strip if key

      path = key_path || DEFAULT_KEY_FILE
      if File.exist?(path)
        return File.read(path).strip
      end

      env_key = ENV[ENV_VAR]
      return env_key.strip if env_key && !env_key.empty?

      raise KeyError, "No encryption key found. Provide key:, key_path:, or set #{ENV_VAR}"
    end
  end
end
