# typed: strict
# frozen_string_literal: true

require "optparse"
require "sorbet-runtime"

module Rooq
  class CLI
    extend T::Sig

    sig { params(args: T::Array[String]).void }
    def initialize(args)
      @args = args
      @options = T.let({
        schema: "public",
        output: nil,
        typed: true,
        database: nil,
        host: "localhost",
        port: 5432,
        username: nil,
        password: nil
      }, T::Hash[Symbol, T.untyped])
    end

    sig { returns(Integer) }
    def run
      parse_options!

      case @args.first
      when "generate", "gen", "g"
        generate_command
      when "version", "-v", "--version"
        version_command
      when "help", "-h", "--help", nil
        help_command
      else
        $stderr.puts "Unknown command: #{@args.first}"
        $stderr.puts "Run 'rooq help' for usage information."
        1
      end
    rescue StandardError => e
      $stderr.puts "Error: #{e.message}"
      $stderr.puts e.backtrace.first(5).join("\n") if ENV["DEBUG"]
      1
    end

    private

    sig { void }
    def parse_options!
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: rooq <command> [options]"

        opts.on("-d", "--database DATABASE", "Database name (required)") do |v|
          @options[:database] = v
        end

        opts.on("-h", "--host HOST", "Database host (default: localhost)") do |v|
          @options[:host] = v
        end

        opts.on("-p", "--port PORT", Integer, "Database port (default: 5432)") do |v|
          @options[:port] = v
        end

        opts.on("-U", "--username USERNAME", "Database username") do |v|
          @options[:username] = v
        end

        opts.on("-W", "--password PASSWORD", "Database password") do |v|
          @options[:password] = v
        end

        opts.on("-s", "--schema SCHEMA", "Schema name (default: public)") do |v|
          @options[:schema] = v
        end

        opts.on("-o", "--output FILE", "Output file (default: stdout)") do |v|
          @options[:output] = v
        end

        opts.on("--[no-]typed", "Generate Sorbet types (default: true)") do |v|
          @options[:typed] = v
        end

        opts.on("--help", "Show this help message") do
          puts opts
          exit 0
        end
      end

      parser.parse!(@args)
    end

    sig { returns(Integer) }
    def generate_command
      @args.shift # Remove the "generate" command

      unless @options[:database]
        $stderr.puts "Error: Database name is required (-d DATABASE)"
        $stderr.puts "Run 'rooq help' for usage information."
        return 1
      end

      require "pg"

      connection = connect_to_database
      introspector = Generator::Introspector.new(connection)
      schema_info = introspector.introspect_schema(schema: @options[:schema])

      generator = Generator::CodeGenerator.new(schema_info, typed: @options[:typed])
      code = generator.generate

      if @options[:output]
        File.write(@options[:output], code)
        puts "Generated #{@options[:output]}"
      else
        puts code
      end

      connection.close
      0
    end

    sig { returns(T.untyped) }
    def connect_to_database
      connection_params = {
        dbname: @options[:database],
        host: @options[:host],
        port: @options[:port]
      }

      connection_params[:user] = @options[:username] if @options[:username]
      connection_params[:password] = @options[:password] if @options[:password]

      # Also check environment variables
      connection_params[:user] ||= ENV["PGUSER"]
      connection_params[:password] ||= ENV["PGPASSWORD"]
      connection_params[:host] = ENV["PGHOST"] if ENV["PGHOST"]
      connection_params[:port] = ENV["PGPORT"].to_i if ENV["PGPORT"]

      PG.connect(connection_params)
    end

    sig { returns(Integer) }
    def version_command
      puts "rooq #{Rooq::VERSION}"
      0
    end

    sig { returns(Integer) }
    def help_command
      puts <<~HELP
        rOOQ - A jOOQ-inspired query builder for Ruby

        Usage: rooq <command> [options]

        Commands:
          generate, gen, g    Generate Ruby table definitions from database schema
          version             Show version
          help                Show this help message

        Options for 'generate':
          -d, --database DATABASE   Database name (required)
          -h, --host HOST           Database host (default: localhost)
          -p, --port PORT           Database port (default: 5432)
          -U, --username USERNAME   Database username
          -W, --password PASSWORD   Database password
          -s, --schema SCHEMA       Schema name (default: public)
          -o, --output FILE         Output file (default: stdout)
          --[no-]typed              Generate Sorbet types (default: true)

        Environment Variables:
          PGHOST      Default database host
          PGPORT      Default database port
          PGUSER      Default database username
          PGPASSWORD  Default database password

        Examples:
          # Generate schema to stdout
          rooq generate -d myapp_development

          # Generate schema to file with Sorbet types
          rooq generate -d myapp_development -o lib/schema.rb

          # Generate schema without Sorbet types
          rooq generate -d myapp_development -o lib/schema.rb --no-typed

          # Connect to remote database
          rooq generate -d myapp -h db.example.com -U postgres -W secret -o lib/schema.rb

      HELP
      0
    end
  end
end
