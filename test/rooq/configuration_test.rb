# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def test_configuration_has_default_dialect
    config = Rooq::Configuration.new

    assert_that(config.dialect).descends_from(Rooq::Dialect::PostgreSQL)
  end

  def test_configuration_accepts_connection_provider
    connection = Object.new
    provider = Rooq::DefaultConnectionProvider.new(connection)
    config = Rooq::Configuration.new(connection_provider: provider)

    assert_that(config.connection_provider).equals(provider)
  end

  def test_configuration_accepts_dialect
    dialect = Rooq::Dialect::PostgreSQL.new
    config = Rooq::Configuration.new(dialect: dialect)

    assert_that(config.dialect).equals(dialect)
  end

  def test_configuration_is_immutable
    config = Rooq::Configuration.new

    assert config.frozen?
  end

  def test_derive_returns_new_configuration
    original = Rooq::Configuration.new
    derived = original.derive(dialect: Rooq::Dialect::PostgreSQL.new)

    refute_equal original.object_id, derived.object_id
  end

  def test_derive_preserves_original_settings
    connection = Object.new
    provider = Rooq::DefaultConnectionProvider.new(connection)
    original = Rooq::Configuration.new(connection_provider: provider)

    derived = original.derive(dialect: Rooq::Dialect::PostgreSQL.new)

    assert_that(derived.connection_provider).equals(provider)
  end

  def test_derive_overrides_specified_settings
    dialect1 = Rooq::Dialect::PostgreSQL.new
    dialect2 = Rooq::Dialect::PostgreSQL.new
    original = Rooq::Configuration.new(dialect: dialect1)

    derived = original.derive(dialect: dialect2)

    assert_that(derived.dialect).equals(dialect2)
  end

  def test_configuration_from_connection
    connection = Object.new
    config = Rooq::Configuration.from_connection(connection)

    assert_that(config.connection_provider).descends_from(Rooq::DefaultConnectionProvider)
    assert_that(config.connection_provider.connection).equals(connection)
  end

  def test_configuration_from_pool
    pool = MockPool.new
    config = Rooq::Configuration.from_pool(pool)

    assert_that(config.connection_provider).descends_from(Rooq::PooledConnectionProvider)
    assert_that(config.connection_provider.pool).equals(pool)
  end

  private

  class MockPool
    def checkout
      Object.new
    end

    def checkin(conn)
    end
  end
end
