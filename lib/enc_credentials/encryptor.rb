require "openssl"
require "base64"
require "securerandom"

module EncCredentials
  # Handles AES-256-GCM encryption and decryption.
  #
  # Encrypted output format: Base64-strict of +nonce (12 bytes) + ciphertext + auth tag (16 bytes)+.
  # A fresh random nonce is generated on every {#encrypt} call.
  class Encryptor
    CIPHER = "aes-256-gcm"
    KEY_LEN = 32
    NONCE_LEN = 12
    TAG_LEN = 16

    # @param key [String] hex-encoded 32-byte key (64 hex characters)
    # @raise [ArgumentError] if the key is not a valid 64-character hex string
    def initialize(key)
      raw = decode_key(key)
      raise ArgumentError, "Key must be #{KEY_LEN} bytes (#{KEY_LEN * 2} hex chars)" unless raw.bytesize == KEY_LEN
      @key = raw
    end

    # Encrypt a plaintext string.
    #
    # @param plaintext [String]
    # @return [String] Base64-encoded encrypted blob
    def encrypt(plaintext)
      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.encrypt
      cipher.key = @key
      nonce = cipher.random_iv
      cipher.auth_data = ""

      ciphertext = cipher.update(plaintext) + cipher.final
      tag = cipher.auth_tag(TAG_LEN)

      Base64.strict_encode64(nonce + ciphertext + tag)
    end

    # Decrypt a Base64-encoded blob produced by {#encrypt}.
    #
    # @param encoded [String] Base64-encoded encrypted blob
    # @return [String] original plaintext
    # @raise [DecryptionError] if the key is wrong or the data is corrupted
    def decrypt(encoded)
      blob = Base64.strict_decode64(encoded)
      nonce = blob.byteslice(0, NONCE_LEN)
      tag = blob.byteslice(-TAG_LEN, TAG_LEN)
      ciphertext = blob.byteslice(NONCE_LEN, blob.bytesize - NONCE_LEN - TAG_LEN)

      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.decrypt
      cipher.key = @key
      cipher.iv = nonce
      cipher.auth_tag = tag
      cipher.auth_data = ""

      cipher.update(ciphertext) + cipher.final
    rescue OpenSSL::Cipher::CipherError, ArgumentError
      # ArgumentError covers malformed Base64 (e.g. truncated file)
      raise DecryptionError, "Decryption failed — wrong key or corrupted file"
    end

    # Generate a new random key suitable for use with this class.
    #
    # @return [String] 64-character lowercase hex string
    def self.generate_key
      SecureRandom.bytes(KEY_LEN).unpack1("H*")
    end

    private

    def decode_key(key)
      key = key.strip
      return [key].pack("H*") if key =~ /\A[0-9a-fA-F]{#{KEY_LEN * 2}}\z/
      raise ArgumentError, "Key must be a #{KEY_LEN * 2}-character hex string"
    end
  end
end
