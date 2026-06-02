require "test_helper"
require "tmpdir"

class TestStore < Minitest::Test
  YAML_FIXTURE = <<~YAML
    database:
      host: localhost
      password: secret
    api_key: abc123
  YAML

  def setup
    @tmpdir = Dir.mktmpdir
    @key = EncCredentials::Encryptor.generate_key
    @creds_path = File.join(@tmpdir, "credentials.yml.enc")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def store_with(yaml)
    s = EncCredentials::Store.new(@creds_path, key: @key)
    s.write!(yaml)
    EncCredentials::Store.new(@creds_path, key: @key)
  end

  def test_bracket_access_top_level_scalar
    assert_equal "abc123", store_with(YAML_FIXTURE)[:api_key]
  end

  def test_method_access_top_level_scalar
    assert_equal "abc123", store_with(YAML_FIXTURE).api_key
  end

  def test_chained_method_access_nested_value
    assert_equal "secret", store_with(YAML_FIXTURE).database.password
  end

  def test_dig_nested_value
    assert_equal "localhost", store_with(YAML_FIXTURE).dig(:database, :host)
  end

  def test_missing_key_returns_nil
    assert_nil store_with(YAML_FIXTURE)[:missing]
  end

  def test_key_predicate_for_missing_key
    refute store_with(YAML_FIXTURE).key?(:missing)
  end

  def test_key_predicate_for_present_key
    assert store_with(YAML_FIXTURE).key?(:api_key)
  end

  def test_empty_file_returns_nil_for_any_key
    store = EncCredentials::Store.new(@creds_path, key: @key)
    assert_nil store[:anything]
  end

  def test_round_trip_preserves_values
    store = store_with("foo: bar\nbaz: 42\n")
    assert_equal "bar", store.foo
    assert_equal 42, store.baz
  end

  def test_raises_key_error_with_no_key_available
    key_path = File.join(@tmpdir, "missing.key")
    assert_raises(EncCredentials::KeyError) do
      EncCredentials::Store.new(@creds_path, key_path: key_path)
    end
  end

  def test_reads_key_from_key_file
    key_path = File.join(@tmpdir, "my.key")
    File.write(key_path, @key)
    store = EncCredentials::Store.new(@creds_path, key_path: key_path)
    store.write!("x: 1\n")
    assert_equal 1, EncCredentials::Store.new(@creds_path, key_path: key_path).x
  end

  def test_reads_key_from_environment_variable
    original = ENV[EncCredentials::KeyResolver::ENV_VAR]
    begin
      ENV[EncCredentials::KeyResolver::ENV_VAR] = @key
      store = EncCredentials::Store.new(@creds_path)
      store.write!("x: 1\n")
      assert_equal 1, EncCredentials::Store.new(@creds_path).x
    ensure
      ENV[EncCredentials::KeyResolver::ENV_VAR] = original
    end
  end
end
