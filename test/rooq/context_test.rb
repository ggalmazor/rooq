# frozen_string_literal: true

require "test_helper"

class ContextTest < Minitest::Test
  def setup
    @books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
    end
  end

  # Creation

  def test_context_from_configuration
    connection = MockConnection.new
    config = Rooq::Configuration.from_connection(connection)

    context = Rooq::Context.new(config)

    assert_that(context.configuration).equals(config)
  end

  def test_context_from_connection
    connection = MockConnection.new

    context = Rooq::Context.using(connection)

    assert_that(context.configuration.connection_provider).descends_from(Rooq::DefaultConnectionProvider)
  end

  def test_context_from_pool
    pool = MockPool.new

    context = Rooq::Context.using_pool(pool)

    assert_that(context.configuration.connection_provider).descends_from(Rooq::PooledConnectionProvider)
  end

  # Query execution

  def test_execute_runs_query
    connection = MockConnection.new
    context = Rooq::Context.using(connection)
    query = Rooq::DSL.select(@books.TITLE).from(@books)

    context.execute(query)

    assert_that(connection.last_sql).equals("SELECT books.title FROM books")
  end

  def test_execute_returns_result
    connection = MockConnection.new([{ "title" => "Ruby" }])
    context = Rooq::Context.using(connection)
    query = Rooq::DSL.select(@books.TITLE).from(@books)

    result = context.execute(query)

    assert_that(result.to_a).has_size(1)
  end

  def test_fetch_one_returns_single_row_with_symbol_keys
    connection = MockConnection.new([{ "title" => "Ruby" }])
    context = Rooq::Context.using(connection)
    query = Rooq::DSL.select(@books.TITLE).from(@books).limit(1)

    result = context.fetch_one(query)

    assert_that(result[:title]).equals("Ruby")
  end

  def test_fetch_one_returns_nil_when_no_results
    connection = MockConnection.new([])
    context = Rooq::Context.using(connection)
    query = Rooq::DSL.select(@books.TITLE).from(@books).where(@books.ID.eq(999))

    result = context.fetch_one(query)

    assert_that(result).is(nil_value)
  end

  def test_fetch_all_returns_array_with_symbol_keys
    connection = MockConnection.new([{ "title" => "Ruby" }, { "title" => "Python" }])
    context = Rooq::Context.using(connection)
    query = Rooq::DSL.select(@books.TITLE).from(@books)

    result = context.fetch_all(query)

    assert_that(result).has_size(2)
    assert_that(result[0][:title]).equals("Ruby")
  end

  # Parameter conversion

  def test_execute_converts_time_parameters
    connection = MockConnection.new([])
    context = Rooq::Context.using(connection)
    time = Time.new(2024, 1, 15, 10, 30, 0, "+00:00")
    query = Rooq::DSL.select(@books.TITLE).from(@books).where(@books.ID.eq(time))

    context.execute(query)

    assert connection.last_params[0].include?("2024-01-15")
  end

  def test_execute_converts_hash_parameters_to_json
    connection = MockConnection.new([])
    context = Rooq::Context.using(connection)
    metadata = { tags: ["ruby", "sql"] }
    query = Rooq::DSL.select(@books.TITLE).from(@books).where(@books.ID.eq(metadata))

    context.execute(query)

    assert_that(connection.last_params[0]).equals('{"tags":["ruby","sql"]}')
  end

  def test_execute_converts_array_parameters
    connection = MockConnection.new([])
    context = Rooq::Context.using(connection)
    ids = [1, 2, 3]
    query = Rooq::DSL.select(@books.TITLE).from(@books).where(@books.ID.in(ids))

    context.execute(query)

    # IN clause expands to individual params, not array literal
    assert_that(connection.last_params).equals([1, 2, 3])
  end

  # Pooled connection handling

  def test_pooled_context_releases_connection_after_execute
    pool = MockPool.new
    context = Rooq::Context.using_pool(pool)
    query = Rooq::DSL.select(@books.TITLE).from(@books)

    context.execute(query)

    assert_that(pool.checkout_count).equals(1)
    assert_that(pool.checkin_count).equals(1)
  end

  def test_pooled_context_releases_connection_on_error
    pool = MockPool.new(raises: true)
    context = Rooq::Context.using_pool(pool)
    query = Rooq::DSL.select(@books.TITLE).from(@books)

    begin
      context.execute(query)
    rescue RuntimeError
      # expected
    end

    assert_that(pool.checkin_count).equals(1)
  end

  # Transaction support

  def test_transaction_commits_on_success
    connection = MockTransactionalConnection.new
    context = Rooq::Context.using(connection)

    context.transaction do
      query = Rooq::DSL.select(@books.TITLE).from(@books)
      context.execute(query)
    end

    assert connection.committed?
    refute connection.rolled_back?
  end

  def test_transaction_rolls_back_on_error
    connection = MockTransactionalConnection.new(raises_on_query: true)
    context = Rooq::Context.using(connection)

    begin
      context.transaction do
        query = Rooq::DSL.select(@books.TITLE).from(@books)
        context.execute(query)
      end
    rescue RuntimeError
      # expected
    end

    assert connection.rolled_back?
    refute connection.committed?
  end

  private

  class MockConnection
    attr_reader :last_sql, :last_params

    def initialize(results = [])
      @results = results
    end

    def exec_params(sql, params)
      @last_sql = sql
      @last_params = params
      MockResult.new(@results)
    end
  end

  class MockResult
    def initialize(data)
      @data = data
      @fields = data.first&.keys || []
    end

    def ntuples
      @data.length
    end

    def nfields
      @fields.length
    end

    def fname(index)
      @fields[index]
    end

    def ftype(index)
      0 # Default OID
    end

    def getvalue(row, col)
      @data[row][@fields[col]]
    end

    def [](index)
      @data[index]
    end

    def to_a
      @data
    end
  end

  class MockPool
    attr_reader :checkout_count, :checkin_count

    def initialize(raises: false)
      @checkout_count = 0
      @checkin_count = 0
      @raises = raises
    end

    def checkout
      @checkout_count += 1
      conn = @raises ? MockRaisingConnection.new : MockConnection.new([])
      conn
    end

    def checkin(connection)
      @checkin_count += 1
    end
  end

  class MockRaisingConnection
    def exec_params(sql, params)
      raise "Database error"
    end
  end

  class MockTransactionalConnection
    attr_reader :last_sql

    def initialize(raises_on_query: false)
      @committed = false
      @rolled_back = false
      @raises_on_query = raises_on_query
    end

    def exec_params(sql, params)
      @last_sql = sql
      raise "Query error" if @raises_on_query
      MockResult.new([])
    end

    def exec(sql)
      # For BEGIN, COMMIT, ROLLBACK
    end

    def transaction
      yield
      @committed = true
    rescue StandardError
      @rolled_back = true
      raise
    end

    def committed?
      @committed
    end

    def rolled_back?
      @rolled_back
    end
  end
end
