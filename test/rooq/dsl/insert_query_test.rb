# frozen_string_literal: true

require "test_helper"

class InsertQueryTest < Minitest::Test
  def books
    @books ||= Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
      t.field :author_id, :integer
    end
  end

  # basic INSERT

  def test_builds_a_simple_insert_query
    query = Rooq::DSL.insert_into(books)
                     .columns(books.TITLE, books.AUTHOR_ID)
                     .values("Ruby Programming", 1)

    result = query.to_sql

    assert_that(result.sql).equals("INSERT INTO books (title, author_id) VALUES ($1, $2)")
    assert_that(result.params).equals(["Ruby Programming", 1])
  end

  def test_supports_multiple_value_rows
    query = Rooq::DSL.insert_into(books)
                     .columns(books.TITLE, books.AUTHOR_ID)
                     .values("Ruby Programming", 1)
                     .values("Python Programming", 2)

    result = query.to_sql

    assert_that(result.sql).equals("INSERT INTO books (title, author_id) VALUES ($1, $2), ($3, $4)")
    assert_that(result.params).equals(["Ruby Programming", 1, "Python Programming", 2])
  end

  # RETURNING clause

  def test_returning_adds_returning_with_specified_fields
    query = Rooq::DSL.insert_into(books)
                     .columns(books.TITLE)
                     .values("Ruby Programming")
                     .returning(books.ID)

    result = query.to_sql

    assert_that(result.sql).equals("INSERT INTO books (title) VALUES ($1) RETURNING books.id")
  end

  def test_returning_supports_multiple_fields
    query = Rooq::DSL.insert_into(books)
                     .columns(books.TITLE)
                     .values("Ruby Programming")
                     .returning(books.ID, books.TITLE)

    result = query.to_sql

    assert_that(result.sql).equals("INSERT INTO books (title) VALUES ($1) RETURNING books.id, books.title")
  end
end
