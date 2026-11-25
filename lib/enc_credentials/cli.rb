require "optparse"
require "tempfile"
require_relative "store"
require_relative "encryptor"
require_relative "key_resolver"

module EncCredentials
  class CLI
    GITIGNORE_ENTRY = "credentials.key\n"

    def initialize(argv)
      @argv = argv
      @credentials_file = Store::DEFAULT_CREDENTIALS_FILE
      @key_file = KeyResolver::DEFAULT_KEY_FILE
    end

    def run
      command = @argv.shift
      parse_options

      case command
      when "setup" then setup
      when "edit" then edit
      when "show" then show
      when "diff" then diff_file
      else
        usage
      end
    end

    private

    def parse_options
      OptionParser.new do |opts|
        opts.on("-c", "--credentials FILE", "Credentials file (default: #{Store::DEFAULT_CREDENTIALS_FILE})") do |f|
          @credentials_file = f
        end
        opts.on("-k", "--key FILE", "Key file (default: #{KeyResolver::DEFAULT_KEY_FILE})") do |f|
          @key_file = f
        end
      end.parse!(@argv)
    end

    def setup
      if File.exist?(@key_file)
        abort "Key file #{@key_file} already exists. Delete it first if you want to regenerate."
      end

      key = Encryptor.generate_key
      File.write(@key_file, key)
      File.chmod(0o600, @key_file)
      puts "Created #{@key_file}"

      unless File.exist?(@credentials_file)
        store = Store.new(@credentials_file, key_path: @key_file)
        store.write!(default_credentials_yaml)
        puts "Created #{@credentials_file}"
      end

      append_gitignore
      append_gitattributes
      configure_git_diff_driver
    end

    def edit
      store = Store.new(@credentials_file, key_path: @key_file)
      plaintext = store.read_plaintext
      plaintext = default_credentials_yaml if plaintext.empty?

      Tempfile.create(["enc_credentials", ".yml"]) do |tmp|
        tmp.write(plaintext)
        tmp.flush

        editor = ENV["EDITOR"] || ENV["VISUAL"] || "vi"
        system("#{editor} #{tmp.path}")

        new_content = File.read(tmp.path)
        if new_content == plaintext
          puts "No changes."
        else
          validate_yaml!(new_content)
          store.write!(new_content)
          puts "#{@credentials_file} saved."
        end
      end
    end

    def show
      store = Store.new(@credentials_file, key_path: @key_file)
      plaintext = store.read_plaintext
      if plaintext.empty?
        puts "(empty)"
      else
        puts plaintext
      end
    end

    def diff_file
      file = @argv.shift || @credentials_file
      store = Store.new(file, key_path: @key_file)
      plaintext = store.read_plaintext
      print plaintext
    rescue EncCredentials::KeyError, EncCredentials::DecryptionError => e
      warn "enc-creds diff: #{e.message}"
      print File.read(file) if File.exist?(file)
    end

    def validate_yaml!(content)
      YAML.safe_load(content)
    rescue Psych::SyntaxError => e
      abort "YAML syntax error: #{e.message}\nCredentials not saved."
    end

    def append_gitattributes
      gitattributes = ".gitattributes"
      entry = "*.yml.enc diff=enc_credentials\n"
      if File.exist?(gitattributes)
        existing = File.read(gitattributes)
        unless existing.include?("diff=enc_credentials")
          File.open(gitattributes, "a") { |f| f.write(entry) }
          puts "Added diff driver entry to .gitattributes"
        end
      else
        File.write(gitattributes, entry)
        puts "Created .gitattributes with diff driver entry"
      end
    end

    def configure_git_diff_driver
      textconv = if @key_file == KeyResolver::DEFAULT_KEY_FILE
        "enc-creds diff"
      else
        "enc-creds diff -k #{@key_file}"
      end

      if system("git", "config", "diff.enc_credentials.textconv", textconv, err: File::NULL)
        puts "Configured git diff driver (diff.enc_credentials.textconv)"
      else
        warn "Could not configure git diff driver — run manually:"
        warn "  git config diff.enc_credentials.textconv '#{textconv}'"
      end
    end

    def append_gitignore
      gitignore = ".gitignore"
      if File.exist?(gitignore)
        existing = File.read(gitignore)
        unless existing.include?(@key_file) || existing.include?("credentials.key")
          File.open(gitignore, "a") { |f| f.write("\n#{@key_file}\n") }
          puts "Added #{@key_file} to .gitignore"
        end
      else
        File.write(gitignore, "#{@key_file}\n")
        puts "Created .gitignore with #{@key_file}"
      end
    end

    def default_credentials_yaml
      <<~YAML
        # Add your credentials here.
        # Syntax is standard YAML.
        #
        # database:
        #   host: localhost
        #   password: secret
        #
        # api_key: abc123
      YAML
    end

    def usage
      warn <<~USAGE
        Usage: enc-creds COMMAND [options]

        Commands:
          setup   Generate a new key and empty credentials file
          edit    Open credentials in $EDITOR
          show    Print decrypted credentials to stdout
          diff    Print decrypted credentials (used as a git textconv driver)

        Options:
          -c, --credentials FILE   Credentials file (default: #{Store::DEFAULT_CREDENTIALS_FILE})
          -k, --key FILE           Key file (default: #{KeyResolver::DEFAULT_KEY_FILE})
      USAGE
      exit 1
    end
  end
end
