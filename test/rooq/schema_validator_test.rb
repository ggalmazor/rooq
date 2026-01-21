# frozen_string_literal: true

require "test_helper"

class SchemaValidatorTest < Minitest::Test
  def setup
    @connection = MockIntrospectionConnection.new
  end

  # validate

  def test_validate_passes_when_table_and_columns_exist
    @connection.set_tables(["books"])
    @connection.set_columns("books", [column("id"), column("title"), column("author")])

    books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
    end

    validator = Rooq::SchemaValidator.new(@connection)
    result = validator.validate([books])

    assert_that(result).equals(true)
  end

  def test_validate_raises_when_table_does_not_exist
    @connection.set_tables(["users"])

    books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
    end

    validator = Rooq::SchemaValidator.new(@connection)

    error = assert_raises(Rooq::SchemaValidationError) { validator.validate([books]) }
    assert_that(error.message).matches_pattern(/Table 'books' does not exist/)
  end

  def test_validate_raises_when_column_does_not_exist
    @connection.set_tables(["books"])
    @connection.set_columns("books", [column("id"), column("title")])

    books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
      t.field :nonexistent, :string
    end

    validator = Rooq::SchemaValidator.new(@connection)

    error = assert_raises(Rooq::SchemaValidationError) { validator.validate([books]) }
    assert_that(error.message).matches_pattern(/Column 'nonexistent'.*does not exist/)
  end

  def test_validate_collects_multiple_errors
    @connection.set_tables(["books"])
    @connection.set_columns("books", [column("id")])

    books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :missing1, :string
      t.field :missing2, :string
    end

    validator = Rooq::SchemaValidator.new(@connection)

    error = assert_raises(Rooq::SchemaValidationError) { validator.validate([books]) }
    assert_that(error.validation_errors).has_size(2)
  end

  def test_validate_validates_multiple_tables
    @connection.set_tables(["books", "authors"])
    @connection.set_columns("books", [column("id"), column("title")])
    @connection.set_columns("authors", [column("id"), column("name")])

    books = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
    end

    authors = Rooq::Table.new(:authors) do |t|
      t.field :id, :integer
      t.field :name, :string
    end

    validator = Rooq::SchemaValidator.new(@connection)
    result = validator.validate([books, authors])

    assert_that(result).equals(true)
  end

  private

  def column(name)
    Rooq::Generator::ColumnInfo.new(
      name: name,
      type: :string,
      pg_type: "text",
      nullable: true,
      default: nil,
      max_length: nil,
      precision: nil,
      scale: nil
    )
  end

  class MockIntrospectionConnection
    def initialize
      @tables = []
      @columns = {}
    end

    def set_tables(tables)
      @tables = tables
    end

    def set_columns(table_name, columns)
      @columns[table_name] = columns
    end

    def exec_params(sql, params)
      if sql.include?("information_schema.tables")
        MockResult.new(@tables.map { |t| { "table_name" => t } })
      elsif sql.include?("information_schema.columns")
        table_name = params[1]
        columns = @columns[table_name] || []
        MockResult.new(columns.map do |c|
          {
            "column_name" => c.name,
            "data_type" => c.pg_type,
            "is_nullable" => c.nullable ? "YES" : "NO",
            "column_default" => c.default,
            "character_maximum_length" => c.max_length,
            "numeric_precision" => c.precision,
            "numeric_scale" => c.scale
          }
        end)
      else
        MockResult.new([])
      end
    end
  end

  class MockResult
    include Enumerable

    def initialize(rows)
      @rows = rows
    end

    def each(&block)
      @rows.each(&block)
    end

    def map(&block)
      @rows.map(&block)
    end
  end
end
