# frozen_string_literal: true

module Rooq
  # Configuration holds all settings for a Rooq context.
  # Configurations are immutable - use #derive to create modified copies.
  #
  # Inspired by jOOQ's Configuration class.
  # @see https://www.jooq.org/javadoc/latest/org.jooq/org/jooq/Configuration.html
  class Configuration
    attr_reader :connection_provider, :dialect

    # Create a new configuration.
    # @param connection_provider [ConnectionProvider] the connection provider
    # @param dialect [Dialect::Base] the SQL dialect
    def initialize(connection_provider: nil, dialect: nil)
      @connection_provider = connection_provider
      @dialect = dialect || Dialect::PostgreSQL.new
      freeze
    end

    # Create a new configuration from a single connection.
    # The connection lifecycle is managed externally.
    # @param connection [Object] a database connection
    # @param dialect [Dialect::Base] the SQL dialect
    # @return [Configuration]
    def self.from_connection(connection, dialect: nil)
      new(
        connection_provider: DefaultConnectionProvider.new(connection),
        dialect: dialect
      )
    end

    # Create a new configuration from a connection pool.
    # Connections are acquired and released per query.
    # @param pool [ConnectionPool] a connection pool
    # @param dialect [Dialect::Base] the SQL dialect
    # @return [Configuration]
    def self.from_pool(pool, dialect: nil)
      new(
        connection_provider: PooledConnectionProvider.new(pool),
        dialect: dialect
      )
    end

    # Create a derived configuration with some settings overridden.
    # @param connection_provider [ConnectionProvider] new connection provider (optional)
    # @param dialect [Dialect::Base] new dialect (optional)
    # @return [Configuration] a new configuration
    def derive(connection_provider: nil, dialect: nil)
      Configuration.new(
        connection_provider: connection_provider || @connection_provider,
        dialect: dialect || @dialect
      )
    end
  end
end
