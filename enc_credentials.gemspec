require_relative "lib/enc_credentials/version"

Gem::Specification.new do |spec|
  spec.name = "enc_credentials"
  spec.version = EncCredentials::VERSION
  spec.authors = ["Scott Wright"]
  spec.email = ["scott@wrightzone.com"]

  spec.summary = "Symmetrically encrypted credential store, inspired by Rails encrypted credentials"
  spec.description = "Store credentials in an AES-256-GCM encrypted YAML file with key-file or environment-variable key resolution."
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "bin/*", "LICENSE", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["enc-creds"]
  spec.require_paths = ["lib"]

  spec.add_dependency "base64"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "standard", "~> 1.0"
end
