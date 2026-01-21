# frozen_string_literal: true

module Rooq
  # Abstract interface for connection lifecycle management.
  # Implementations control how connections are acquired and released.
  #
  # This is inspired by jOOQ's ConnectionProvider interface.
  # @see https://www.jooq.org/javadoc/latest/org.jooq/org/jooq/ConnectionProvider.html
  class ConnectionProvider
    # Acquire a connection for query execution.
    # @return [Object] a database connection
    # @raise [NotImplementedError] if not implemented by subclass
    def acquire
      raise NotImplementedError, "#{self.class} must implement #acquire"
    end

    # Release a previously acquired connection.
    # @param connection [Object] the connection to release
    # @raise [NotImplementedError] if not implemented by subclass
    def release(connection)
      raise NotImplementedError, "#{self.class} must implement #release"
    end

    # Execute a block with an acquired connection, ensuring release.
    # @yield [connection] the acquired connection
    # @return [Object] the result of the block
    def with_connection
      connection = acquire
      begin
        yield connection
      ensure
        release(connection)
      end
    end
  end

  # A connection provider that wraps a single connection.
  # The connection lifecycle is managed externally by the caller.
  # Release is a no-op - the connection stays open until closed externally.
  #
  # Use this when you want to control transactions and connection lifecycle yourself.
  class DefaultConnectionProvider < ConnectionProvider
    attr_reader :connection

    # @param connection [Object] the connection to wrap
    def initialize(connection)
      super()
      @connection = connection
    end

    # Always returns the same connection instance.
    # @return [Object] the wrapped connection
    def acquire
      @connection
    end

    # No-op - the connection lifecycle is managed externally.
    # @param connection [Object] the connection (ignored)
    def release(connection)
      # No-op: connection lifecycle is managed externally
    end
  end

  # A connection provider that acquires connections from a pool.
  # Connections are returned to the pool after each query.
  #
  # The pool must respond to #checkout (or #acquire) and optionally #checkin.
  # If the pool doesn't respond to #checkin, the connection's #close method is called.
  class PooledConnectionProvider < ConnectionProvider
    attr_reader :pool

    # @param pool [ConnectionPool] a connection pool
    def initialize(pool)
      super()
      @pool = pool
    end

    # Acquire a connection from the pool.
    # @return [Object] a database connection
    def acquire
      if @pool.respond_to?(:checkout)
        @pool.checkout
      elsif @pool.respond_to?(:acquire)
        @pool.acquire
      else
        raise Error, "Pool must respond to #checkout or #acquire"
      end
    end

    # Release a connection back to the pool.
    # @param connection [Object] the connection to release
    def release(connection)
      if @pool.respond_to?(:checkin)
        @pool.checkin(connection)
      elsif connection.respond_to?(:close)
        connection.close
      end
    end
  end

  # Abstract interface for connection pools.
  # Implementations manage a pool of reusable database connections.
  class ConnectionPool
    # Check out a connection from the pool.
    # @return [Object] a database connection
    def checkout
      raise NotImplementedError, "#{self.class} must implement #checkout"
    end

    # Check in a connection back to the pool.
    # @param connection [Object] the connection to return
    def checkin(connection)
      raise NotImplementedError, "#{self.class} must implement #checkin"
    end

    # @return [Integer] total pool size
    def size
      raise NotImplementedError, "#{self.class} must implement #size"
    end

    # @return [Integer] number of available connections
    def available
      raise NotImplementedError, "#{self.class} must implement #available"
    end

    # Shutdown the pool and close all connections.
    def shutdown
      raise NotImplementedError, "#{self.class} must implement #shutdown"
    end
  end
end
