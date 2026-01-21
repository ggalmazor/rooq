# frozen_string_literal: true

require "test_helper"

class ExecutorTest < Minitest::Test
  def books
    @books ||= Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
    end
  end

  # execute

  def test_execute_calls_connection_with_sql_and_params
    connection = MockConnection.new([{ "id" => "1", "title" => "Ruby" }])
    executor = Rooq::Executor.new(connection)

    query = Rooq::DSL.select(books.ID, books.TITLE)
                     .from(books)
                     .where(books.ID.eq(1))

    executor.execute(query)

    assert_that(connection.last_sql).equals("SELECT books.id, books.title FROM books WHERE books.id = $1")
    assert_that(connection.last_params).equals([1])
  end

  # fetch_one

  def test_fetch_one_returns_first_row
    connection = MockConnection.new([{ "id" => "1", "title" => "Ruby" }])
    executor = Rooq::Executor.new(connection)

    query = Rooq::DSL.select(books.ID, books.TITLE).from(books)

    result = executor.fetch_one(query)

    assert_that(result["title"]).equals("Ruby")
  end

  def test_fetch_one_returns_nil_when_no_rows
    connection = MockConnection.new([])
    executor = Rooq::Executor.new(connection)

    query = Rooq::DSL.select(books.ID, books.TITLE).from(books)

    result = executor.fetch_one(query)

    assert_that(result).is(nil_value)
  end

  # fetch_all

  def test_fetch_all_returns_all_rows
    connection = MockConnection.new([
                                      { "id" => "1", "title" => "Ruby" },
                                      { "id" => "2", "title" => "Python" }
                                    ])
    executor = Rooq::Executor.new(connection)

    query = Rooq::DSL.select(books.ID, books.TITLE).from(books)

    result = executor.fetch_all(query)

    assert_that(result).has_size(2)
    assert_that(result[0]["title"]).equals("Ruby")
    assert_that(result[1]["title"]).equals("Python")
  end

  # hooks

  def test_before_execute_hook_is_called
    connection = MockConnection.new([])
    executor = Rooq::Executor.new(connection)
    captured_query = nil

    executor.on_before_execute { |q| captured_query = q }

    query = Rooq::DSL.select(books.TITLE).from(books)
    executor.execute(query)

    assert_that(captured_query).descends_from(Rooq::Dialect::RenderedQuery)
    assert_that(captured_query.sql).equals("SELECT books.title FROM books")
  end

  def test_after_execute_hook_is_called
    connection = MockConnection.new([{ "title" => "Ruby" }])
    executor = Rooq::Executor.new(connection)
    captured_result = nil

    executor.on_after_execute { |_q, result| captured_result = result }

    query = Rooq::DSL.select(books.TITLE).from(books)
    executor.execute(query)

    assert_that(captured_result.to_a).has_size(1)
  end

  class MockConnection
    attr_reader :last_sql, :last_params

    def initialize(rows)
      @rows = rows
    end

    def exec_params(sql, params)
      @last_sql = sql
      @last_params = params
      MockResult.new(@rows)
    end
  end

  class MockResult
    def initialize(rows)
      @rows = rows
    end

    def ntuples
      @rows.length
    end

    def [](index)
      @rows[index]
    end

    def to_a
      @rows
    end
  end
end
