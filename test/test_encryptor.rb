require "test_helper"

class TestEncryptor < Minitest::Test
  def setup
    @key = EncCredentials::Encryptor.generate_key
    @enc = EncCredentials::Encryptor.new(@key)
  end

  def test_generate_key_is_64_hex_chars
    assert_match(/\A[0-9a-f]{64}\z/, @key)
  end

  def test_generate_key_is_unique
    refute_equal @key, EncCredentials::Encryptor.generate_key
  end

  def test_round_trip
    plaintext = "database:\n  password: secret\n"
    assert_equal plaintext, @enc.decrypt(@enc.encrypt(plaintext))
  end

  def test_random_nonce_produces_different_ciphertext
    pt = "same plaintext"
    refute_equal @enc.encrypt(pt), @enc.encrypt(pt)
  end

  def test_wrong_key_raises_decryption_error
    encrypted = @enc.encrypt("secret")
    wrong = EncCredentials::Encryptor.new(EncCredentials::Encryptor.generate_key)
    assert_raises(EncCredentials::DecryptionError) { wrong.decrypt(encrypted) }
  end

  def test_tampered_ciphertext_raises_decryption_error
    encrypted = @enc.encrypt("secret")
    tampered = encrypted.dup
    tampered[-1] = tampered[-1] == "A" ? "B" : "A"
    assert_raises(EncCredentials::DecryptionError) { @enc.decrypt(tampered) }
  end

  def test_short_key_raises_argument_error
    assert_raises(ArgumentError) { EncCredentials::Encryptor.new("abc") }
  end

  def test_non_hex_key_raises_argument_error
    assert_raises(ArgumentError) { EncCredentials::Encryptor.new("z" * 64) }
  end
end
