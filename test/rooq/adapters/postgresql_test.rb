# frozen_string_literal: true

require "test_helper"

class PostgreSQLAdapterTest < Minitest::Test
  # ConnectionPool

  def test_pool_initializes_with_size
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 5) { MockPGConnection.new }

    assert_that(pool.size).equals(5)
  end

  def test_pool_checkout_returns_connection
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 2) { MockPGConnection.new }

    connection = pool.checkout

    assert_that(connection).descends_from(MockPGConnection)
  end

  def test_pool_checkin_returns_connection_to_pool
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 1) { MockPGConnection.new }

    conn1 = pool.checkout
    pool.checkin(conn1)
    conn2 = pool.checkout

    assert_that(conn1.object_id).equals(conn2.object_id)
  end

  def test_pool_available_decreases_on_checkout
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 3) { MockPGConnection.new }

    assert_that(pool.available).equals(3)
    pool.checkout
    assert_that(pool.available).equals(2)
  end

  def test_pool_available_increases_on_checkin
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 2) { MockPGConnection.new }

    conn = pool.checkout
    assert_that(pool.available).equals(1)
    pool.checkin(conn)
    assert_that(pool.available).equals(2)
  end

  def test_pool_shutdown_closes_all_connections
    closed_count = 0
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 3) do
      MockPGConnection.new { closed_count += 1 }
    end

    # Check out and check in to ensure connections are created
    3.times do
      conn = pool.checkout
      pool.checkin(conn)
    end

    pool.shutdown

    assert_that(closed_count).equals(3)
  end

  def test_pool_blocks_when_exhausted
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 1, timeout: 0.1) { MockPGConnection.new }

    pool.checkout

    assert_raises(Rooq::Adapters::PostgreSQL::ConnectionPool::TimeoutError) do
      pool.checkout
    end
  end

  # Context integration

  def test_context_works_with_postgresql_pool
    pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 2) { MockPGConnection.new([{ "id" => 1 }]) }
    ctx = Rooq::Context.using_pool(pool)

    books = Rooq::Table.new(:books) { |t| t.field :id, :integer }
    result = ctx.fetch_one(Rooq::DSL.select(books.ID).from(books))

    assert_that(result[:id]).equals(1)
  end

  private

  class MockPGConnection
    def initialize(results = [], &on_close)
      @results = results
      @on_close = on_close
    end

    def exec_params(sql, params)
      MockResult.new(@results)
    end

    def close
      @on_close&.call
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
      0
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
end
