# frozen_string_literal: true

require "test_helper"

class RecordTest < Minitest::Test
  def setup
    @books_table = Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
      t.field :author, :string
    end

    @connection = MockConnection.new
    @executor = Rooq::Executor.new(@connection)

    # Create a fresh Book class for each test
    @book_class = Class.new(Rooq::Record) do
      self.primary_key = :id
    end
    @book_class.table = @books_table
    @book_class.executor = @executor
  end

  # initialization

  def test_new_record_stores_attributes
    book = @book_class.new(title: "Ruby Programming", author: "Matz")

    assert_that(book[:title]).equals("Ruby Programming")
    assert_that(book[:author]).equals("Matz")
  end

  def test_new_record_is_not_persisted
    book = @book_class.new(title: "Ruby")

    assert_that(book.persisted?).equals(false)
    assert_that(book.new_record?).equals(true)
  end

  # dirty tracking

  def test_new_record_tracks_all_attributes_as_changed
    book = @book_class.new(title: "Ruby", author: "Matz")

    assert_that(book.changed?).equals(true)
    assert_that(book.changes).has_key(:title)
    assert_that(book.changes).has_key(:author)
  end

  def test_setting_attribute_marks_it_as_changed
    book = @book_class.new(title: "Ruby")
    book.instance_variable_set(:@changed_attributes, {})

    book[:author] = "Matz"

    assert_that(book.changed?).equals(true)
    assert_that(book.changes[:author]).equals("Matz")
  end

  def test_setting_same_value_does_not_mark_as_changed
    book = @book_class.new(title: "Ruby")
    book.instance_variable_set(:@changed_attributes, {})

    book[:title] = "Ruby"

    assert_that(book.changed?).equals(false)
  end

  # find

  def test_find_returns_record_when_found
    @connection.set_result([{ "id" => "1", "title" => "Ruby", "author" => "Matz" }])

    book = @book_class.find(1)

    assert_that(book[:title]).equals("Ruby")
    assert_that(book.persisted?).equals(true)
  end

  def test_find_returns_nil_when_not_found
    @connection.set_result([])

    book = @book_class.find(999)

    assert_that(book).is(nil_value)
  end

  # find_by

  def test_find_by_returns_record_matching_conditions
    @connection.set_result([{ "id" => "1", "title" => "Ruby", "author" => "Matz" }])

    book = @book_class.find_by(title: "Ruby")

    assert_that(book[:title]).equals("Ruby")
  end

  # where

  def test_where_returns_matching_records
    @connection.set_result([
                             { "id" => "1", "title" => "Ruby", "author" => "Matz" },
                             { "id" => "2", "title" => "Python", "author" => "Guido" }
                           ])

    books = @book_class.where(author: "Matz")

    assert_that(books).has_size(2)
  end

  # all

  def test_all_returns_all_records
    @connection.set_result([
                             { "id" => "1", "title" => "Ruby", "author" => "Matz" },
                             { "id" => "2", "title" => "Python", "author" => "Guido" }
                           ])

    books = @book_class.all

    assert_that(books).has_size(2)
  end

  # save (insert)

  def test_save_inserts_new_record
    @connection.set_result([{ "id" => "42" }])

    book = @book_class.new(title: "Ruby", author: "Matz")
    book.save

    assert_that(@connection.last_sql).starts_with("INSERT INTO books")
    assert_that(book[:id]).equals(42)
    assert_that(book.persisted?).equals(true)
    assert_that(book.changed?).equals(false)
  end

  # save (update)

  def test_save_updates_existing_record
    @connection.set_result([{ "id" => "1", "title" => "Ruby", "author" => "Matz" }])
    book = @book_class.find(1)

    book[:title] = "Ruby 3"
    @connection.set_result([])
    book.save

    assert_that(@connection.last_sql).starts_with("UPDATE books SET")
    assert_that(book.changed?).equals(false)
  end

  def test_save_does_nothing_when_no_changes
    @connection.set_result([{ "id" => "1", "title" => "Ruby", "author" => "Matz" }])
    book = @book_class.find(1)

    initial_sql = @connection.last_sql
    book.save

    assert_that(@connection.last_sql).equals(initial_sql)
  end

  # destroy

  def test_destroy_deletes_record
    @connection.set_result([{ "id" => "1", "title" => "Ruby", "author" => "Matz" }])
    book = @book_class.find(1)

    @connection.set_result([])
    result = book.destroy

    assert_that(result).equals(true)
    assert_that(@connection.last_sql).starts_with("DELETE FROM books")
    assert_that(book.persisted?).equals(false)
  end

  def test_destroy_returns_false_for_new_record
    book = @book_class.new(title: "Ruby")

    result = book.destroy

    assert_that(result).equals(false)
  end

  # create

  def test_create_instantiates_and_saves
    @connection.set_result([{ "id" => "42" }])

    book = @book_class.create(title: "Ruby", author: "Matz")

    assert_that(book[:id]).equals(42)
    assert_that(book.persisted?).equals(true)
  end

  class MockConnection
    attr_reader :last_sql, :last_params

    def initialize
      @result = []
    end

    def set_result(rows)
      @result = rows
    end

    def exec_params(sql, params)
      @last_sql = sql
      @last_params = params
      MockResult.new(@result)
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
