# frozen_string_literal: true

module Rooq
  module Adapters
    module PostgreSQL
      # A simple connection pool for PostgreSQL connections.
      # For production use, consider using a more robust pool like connection_pool gem.
      #
      # @example Basic usage
      #   pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 5) do
      #     PG.connect(dbname: 'myapp', host: 'localhost')
      #   end
      #
      #   ctx = Rooq::Context.using_pool(pool)
      #   # ... execute queries ...
      #   pool.shutdown
      #
      # @example With timeout
      #   pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 10, timeout: 5) do
      #     PG.connect(connection_string)
      #   end
      class ConnectionPool < Rooq::ConnectionPool
        class TimeoutError < Rooq::Error; end

        attr_reader :size

        # Create a new connection pool.
        # @param size [Integer] the maximum number of connections
        # @param timeout [Numeric] seconds to wait for a connection (nil = wait forever)
        # @yield the block that creates a new connection
        def initialize(size: 5, timeout: nil, &block)
          super()
          @size = size
          @timeout = timeout
          @create_connection = block
          @mutex = Mutex.new
          @condition = ConditionVariable.new
          @available = []
          @in_use = []
          @shutdown = false

          # Pre-create all connections
          @size.times { @available << @create_connection.call }
        end

        # Check out a connection from the pool.
        # @return [PG::Connection] a database connection
        # @raise [TimeoutError] if timeout expires while waiting
        def checkout
          @mutex.synchronize do
            raise Error, "Pool has been shut down" if @shutdown

            deadline = @timeout ? Time.now + @timeout : nil

            while @available.empty?
              if deadline
                remaining = deadline - Time.now
                raise TimeoutError, "Timed out waiting for connection" if remaining <= 0

                @condition.wait(@mutex, remaining)
              else
                @condition.wait(@mutex)
              end

              raise Error, "Pool has been shut down" if @shutdown
            end

            connection = @available.pop
            @in_use << connection
            connection
          end
        end

        # Check in a connection back to the pool.
        # @param connection [PG::Connection] the connection to return
        def checkin(connection)
          @mutex.synchronize do
            @in_use.delete(connection)
            @available << connection unless @shutdown
            @condition.signal
          end
        end

        # @return [Integer] number of available connections
        def available
          @mutex.synchronize { @available.length }
        end

        # Shutdown the pool and close all connections.
        def shutdown
          @mutex.synchronize do
            @shutdown = true
            @available.each { |conn| conn.close if conn.respond_to?(:close) }
            @in_use.each { |conn| conn.close if conn.respond_to?(:close) }
            @available.clear
            @in_use.clear
            @condition.broadcast
          end
        end
      end

      # Create a Context configured for PostgreSQL.
      # @param connection [PG::Connection] a single connection
      # @return [Rooq::Context]
      def self.context(connection)
        Rooq::Context.using(connection, dialect: Rooq::Dialect::PostgreSQL.new)
      end

      # Create a Context with a connection pool.
      # @param pool [ConnectionPool] a connection pool
      # @return [Rooq::Context]
      def self.pooled_context(pool)
        Rooq::Context.using_pool(pool, dialect: Rooq::Dialect::PostgreSQL.new)
      end
    end
  end
end
