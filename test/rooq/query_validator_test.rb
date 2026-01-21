# frozen_string_literal: true

require "test_helper"

class QueryValidatorTest < Minitest::Test
  def setup
    @books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
      t.field :author_id, :integer
    end

    @authors = Rooq::Table.new(:authors) do |t|
      t.field :id, :integer
      t.field :name, :string
    end

    @validator = Rooq::QueryValidator.new([@books, @authors])
  end

  # validate_select

  def test_validate_select_passes_for_valid_query
    query = Rooq::DSL.select(@books.TITLE)
                     .from(@books)
                     .where(@books.ID.eq(1))

    result = @validator.validate_select(query)

    assert_that(result).equals(true)
  end

  def test_validate_select_raises_for_unknown_table
    unknown_table = Rooq::Table.new(:unknown) do |t|
      t.field :id, :integer
    end

    query = Rooq::DSL.select(unknown_table.ID).from(unknown_table)

    error = assert_raises(Rooq::QueryValidationError) { @validator.validate_select(query) }
    assert_that(error.message).matches_pattern(/Unknown table 'unknown'/)
  end

  def test_validate_select_raises_for_invalid_field_in_condition
    # Create a field that references an unknown table
    bad_field = Rooq::Field.new(:foo, :nonexistent, :string)
    query = Rooq::DSL.select(@books.TITLE)
                     .from(@books)
                     .where(bad_field.eq("test"))

    error = assert_raises(Rooq::QueryValidationError) { @validator.validate_select(query) }
    assert_that(error.message).matches_pattern(/Unknown table 'nonexistent'/)
  end

  def test_validate_select_validates_join_tables
    unknown_table = Rooq::Table.new(:unknown) do |t|
      t.field :id, :integer
    end

    query = Rooq::DSL.select(@books.TITLE)
                     .from(@books)
                     .inner_join(unknown_table).on(@books.AUTHOR_ID.eq(unknown_table.ID))

    error = assert_raises(Rooq::QueryValidationError) { @validator.validate_select(query) }
    assert_that(error.message).matches_pattern(/Unknown table 'unknown'/)
  end

  def test_validate_select_passes_for_valid_join
    query = Rooq::DSL.select(@books.TITLE, @authors.NAME)
                     .from(@books)
                     .inner_join(@authors).on(@books.AUTHOR_ID.eq(@authors.ID))

    result = @validator.validate_select(query)

    assert_that(result).equals(true)
  end

  # validate_insert

  def test_validate_insert_passes_for_valid_query
    query = Rooq::DSL.insert_into(@books)
                     .columns(@books.TITLE, @books.AUTHOR_ID)
                     .values("Ruby", 1)

    result = @validator.validate_insert(query)

    assert_that(result).equals(true)
  end

  def test_validate_insert_raises_for_unknown_table
    unknown_table = Rooq::Table.new(:unknown) do |t|
      t.field :id, :integer
    end

    query = Rooq::DSL.insert_into(unknown_table)
                     .columns(unknown_table.ID)
                     .values(1)

    error = assert_raises(Rooq::QueryValidationError) { @validator.validate_insert(query) }
    assert_that(error.message).matches_pattern(/Unknown table 'unknown'/)
  end

  # validate_update

  def test_validate_update_passes_for_valid_query
    query = Rooq::DSL.update(@books)
                     .set(@books.TITLE, "New Title")
                     .where(@books.ID.eq(1))

    result = @validator.validate_update(query)

    assert_that(result).equals(true)
  end

  def test_validate_update_raises_for_unknown_table
    unknown_table = Rooq::Table.new(:unknown) do |t|
      t.field :id, :integer
      t.field :name, :string
    end

    query = Rooq::DSL.update(unknown_table)
                     .set(unknown_table.NAME, "test")

    error = assert_raises(Rooq::QueryValidationError) { @validator.validate_update(query) }
    assert_that(error.message).matches_pattern(/Unknown table 'unknown'/)
  end

  # validate_delete

  def test_validate_delete_passes_for_valid_query
    query = Rooq::DSL.delete_from(@books)
                     .where(@books.ID.eq(1))

    result = @validator.validate_delete(query)

    assert_that(result).equals(true)
  end

  def test_validate_delete_raises_for_unknown_table
    unknown_table = Rooq::Table.new(:unknown) do |t|
      t.field :id, :integer
    end

    query = Rooq::DSL.delete_from(unknown_table)

    error = assert_raises(Rooq::QueryValidationError) { @validator.validate_delete(query) }
    assert_that(error.message).matches_pattern(/Unknown table 'unknown'/)
  end
end

class ValidatingExecutorTest < Minitest::Test
  def setup
    @books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
    end

    @connection = MockConnection.new([{ "id" => "1", "title" => "Ruby" }])
    @executor = Rooq::ValidatingExecutor.new(@connection, [@books])
  end

  def test_validates_query_before_execution
    unknown_table = Rooq::Table.new(:unknown) do |t|
      t.field :id, :integer
    end

    query = Rooq::DSL.select(unknown_table.ID).from(unknown_table)

    assert_raises(Rooq::QueryValidationError) { @executor.execute(query) }
  end

  def test_executes_valid_query
    query = Rooq::DSL.select(@books.TITLE).from(@books)

    result = @executor.fetch_one(query)

    assert_that(result["title"]).equals("Ruby")
  end

  class MockConnection
    def initialize(rows)
      @rows = rows
    end

    def exec_params(_sql, _params)
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
