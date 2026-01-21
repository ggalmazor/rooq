# frozen_string_literal: true

module Rooq
  # Context is the main entry point for executing queries.
  # It wraps a Configuration and provides methods for query execution.
  #
  # Inspired by jOOQ's DSLContext.
  # @see https://www.jooq.org/javadoc/latest/org.jooq/org/jooq/DSLContext.html
  #
  # @example Using a single connection
  #   connection = PG.connect(dbname: 'myapp')
  #   ctx = Rooq::Context.using(connection)
  #
  #   books = Schema::BOOKS
  #   result = ctx.fetch_all(
  #     Rooq::DSL.select(books.TITLE, books.AUTHOR)
  #              .from(books)
  #              .where(books.PUBLISHED_YEAR.gte(2020))
  #   )
  #   result.each { |row| puts row[:title] }  # Symbol keys
  #
  # @example Using a connection pool
  #   pool = ConnectionPool.new { PG.connect(dbname: 'myapp') }
  #   ctx = Rooq::Context.using_pool(pool)
  #
  #   # Connection is automatically acquired and released per query
  #   result = ctx.fetch_one(
  #     Rooq::DSL.select(books.ID).from(books).where(books.ID.eq(1))
  #   )
  #
  # @example Transactions
  #   ctx.transaction do
  #     ctx.execute(Rooq::DSL.insert_into(books).columns(books.TITLE).values("New Book"))
  #     ctx.execute(Rooq::DSL.update(books).set(books.TITLE, "Updated").where(books.ID.eq(1)))
  #   end
  class Context
    attr_reader :configuration

    # Create a context with the given configuration.
    # @param configuration [Configuration] the configuration
    def initialize(configuration)
      @configuration = configuration
    end

    # Create a context from a single connection.
    # @param connection [Object] a database connection
    # @param dialect [Dialect::Base] the SQL dialect (optional)
    # @return [Context]
    def self.using(connection, dialect: nil)
      new(Configuration.from_connection(connection, dialect: dialect))
    end

    # Create a context from a connection pool.
    # @param pool [ConnectionPool] a connection pool
    # @param dialect [Dialect::Base] the SQL dialect (optional)
    # @return [Context]
    def self.using_pool(pool, dialect: nil)
      new(Configuration.from_pool(pool, dialect: dialect))
    end

    # Execute a query and return a Result object.
    # @param query [DSL::SelectQuery, DSL::InsertQuery, DSL::UpdateQuery, DSL::DeleteQuery] the query
    # @return [Result] the result with symbol keys and type coercion
    def execute(query)
      rendered = render_query(query)
      converted_params = parameter_converter.convert_all(rendered.params)

      raw_result = @configuration.connection_provider.with_connection do |connection|
        connection.exec_params(rendered.sql, converted_params)
      end

      Result.new(raw_result)
    end

    # Execute a query and return a single row with symbol keys.
    # @param query [DSL::SelectQuery] the query
    # @return [Hash, nil] the first row or nil if no results
    def fetch_one(query)
      result = execute(query)
      return nil if result.empty?

      result.first
    end

    # Execute a query and return all rows as an array with symbol keys.
    # @param query [DSL::SelectQuery] the query
    # @return [Array<Hash>] the rows with symbol keys
    def fetch_all(query)
      execute(query).to_a
    end

    # Execute a block within a transaction.
    # Commits on success, rolls back on error.
    # @yield the block to execute within the transaction
    # @return [Object] the result of the block
    def transaction(&block)
      @configuration.connection_provider.with_connection do |connection|
        if connection.respond_to?(:transaction)
          connection.transaction(&block)
        else
          begin
            connection.exec("BEGIN")
            result = yield
            connection.exec("COMMIT")
            result
          rescue StandardError
            connection.exec("ROLLBACK")
            raise
          end
        end
      end
    end

    private

    def parameter_converter
      @parameter_converter ||= ParameterConverter.new
    end

    def render_query(query)
      dialect = @configuration.dialect

      case query
      when DSL::SelectQuery
        dialect.render_select(query)
      when DSL::InsertQuery
        dialect.render_insert(query)
      when DSL::UpdateQuery
        dialect.render_update(query)
      when DSL::DeleteQuery
        dialect.render_delete(query)
      when DSL::SetOperation
        dialect.render_set_operation(query)
      when DSL::OrderedSetOperation
        dialect.render_ordered_set_operation(query)
      else
        raise ArgumentError, "Unknown query type: #{query.class}"
      end
    end
  end
end
