# frozen_string_literal: true

require "test_helper"

class ConnectionProviderTest < Minitest::Test
  # ConnectionProvider interface

  def test_connection_provider_is_abstract
    provider = Rooq::ConnectionProvider.new

    assert_raises(NotImplementedError) { provider.acquire }
    assert_raises(NotImplementedError) { provider.release(nil) }
  end

  # DefaultConnectionProvider

  def test_default_provider_returns_same_connection
    connection = Object.new
    provider = Rooq::DefaultConnectionProvider.new(connection)

    acquired = provider.acquire

    assert_that(acquired).equals(connection)
  end

  def test_default_provider_always_returns_same_connection
    connection = Object.new
    provider = Rooq::DefaultConnectionProvider.new(connection)

    first = provider.acquire
    provider.release(first)
    second = provider.acquire

    assert_that(first).equals(second)
  end

  def test_default_provider_release_is_noop
    connection = Object.new
    provider = Rooq::DefaultConnectionProvider.new(connection)

    acquired = provider.acquire
    provider.release(acquired)

    assert_that(provider.acquire).equals(connection)
  end

  # PooledConnectionProvider

  def test_pooled_provider_acquires_from_pool
    pool = MockConnectionPool.new
    provider = Rooq::PooledConnectionProvider.new(pool)

    connection = provider.acquire

    refute_nil connection
    assert_that(pool.checkout_count).equals(1)
  end

  def test_pooled_provider_releases_back_to_pool
    pool = MockConnectionPool.new
    provider = Rooq::PooledConnectionProvider.new(pool)

    connection = provider.acquire
    provider.release(connection)

    assert_that(pool.checkin_count).equals(1)
  end

  def test_pooled_provider_calls_close_if_no_checkin_method
    connection = MockClosableConnection.new
    pool = MockSimplePool.new(connection)
    provider = Rooq::PooledConnectionProvider.new(pool)

    acquired = provider.acquire
    provider.release(acquired)

    assert connection.closed?
  end

  # ConnectionPool interface

  def test_connection_pool_is_abstract
    pool = Rooq::ConnectionPool.new

    assert_raises(NotImplementedError) { pool.checkout }
    assert_raises(NotImplementedError) { pool.checkin(nil) }
    assert_raises(NotImplementedError) { pool.size }
    assert_raises(NotImplementedError) { pool.available }
    assert_raises(NotImplementedError) { pool.shutdown }
  end

  # with_connection block helper

  def test_default_provider_with_connection_yields_connection
    connection = Object.new
    provider = Rooq::DefaultConnectionProvider.new(connection)
    yielded = nil

    provider.with_connection { |conn| yielded = conn }

    assert_that(yielded).equals(connection)
  end

  def test_pooled_provider_with_connection_releases_after_block
    pool = MockConnectionPool.new
    provider = Rooq::PooledConnectionProvider.new(pool)

    provider.with_connection { |_conn| }

    assert_that(pool.checkout_count).equals(1)
    assert_that(pool.checkin_count).equals(1)
  end

  def test_with_connection_releases_on_exception
    pool = MockConnectionPool.new
    provider = Rooq::PooledConnectionProvider.new(pool)

    begin
      provider.with_connection { |_conn| raise "test error" }
    rescue RuntimeError
      # expected
    end

    assert_that(pool.checkin_count).equals(1)
  end

  private

  class MockConnectionPool
    attr_reader :checkout_count, :checkin_count

    def initialize
      @checkout_count = 0
      @checkin_count = 0
      @connections = []
    end

    def checkout
      @checkout_count += 1
      conn = Object.new
      @connections << conn
      conn
    end

    def checkin(connection)
      @checkin_count += 1
      @connections.delete(connection)
    end
  end

  class MockSimplePool
    def initialize(connection)
      @connection = connection
    end

    def checkout
      @connection
    end
  end

  class MockClosableConnection
    def initialize
      @closed = false
    end

    def close
      @closed = true
    end

    def closed?
      @closed
    end
  end
end
