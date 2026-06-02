module EncCredentials
  # A read-only wrapper around a credentials hash that supports method-style,
  # bracket, and +dig+ access, with automatic symbol-key normalization.
  #
  # All keys are converted to symbols at construction time, so string and symbol
  # keys are interchangeable at read time.
  #
  # @example
  #   ch = CredentialHash.new("database" => { "password" => "secret" })
  #   ch.database.password    #=> "secret"
  #   ch[:database][:password] #=> "secret"
  #   ch["database"]["password"] #=> "secret"
  class CredentialHash
    # @param data [Hash, nil]
    def initialize(data)
      @data = deep_symbolize(data || {})
    end

    # @param key [Symbol, String]
    # @return [CredentialHash, Object, nil]
    def [](key)
      value = @data[key.to_sym]
      wrap(value)
    end

    # @param keys [Array<Symbol, String>]
    # @return [CredentialHash, Object, nil]
    def dig(*keys)
      keys.reduce(self) do |obj, key|
        return nil unless obj.is_a?(CredentialHash)
        obj[key]
      end
    end

    # @return [Hash] the underlying symbolized hash
    def to_h
      @data
    end

    # @param key [Symbol, String]
    # @return [Boolean]
    def key?(key)
      @data.key?(key.to_sym)
    end

    def respond_to_missing?(name, include_private = false)
      @data.key?(name.to_sym) || super
    end

    def method_missing(name, *args)
      return super unless @data.key?(name.to_sym)
      wrap(@data[name.to_sym])
    end

    private

    def wrap(value)
      case value
      when Hash then CredentialHash.new(value)
      else value
      end
    end

    def deep_symbolize(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_sym).transform_values { |v| deep_symbolize(v) }
      when Array
        obj.map { |v| deep_symbolize(v) }
      else
        obj
      end
    end
  end
end
