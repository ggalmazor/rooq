# frozen_string_literal: true

require "test_helper"

class UpdateQueryTest < Minitest::Test
  def books
    @books ||= Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
      t.field :author_id, :integer
    end
  end

  # basic UPDATE

  def test_builds_a_simple_update_query
    query = Rooq::DSL.update(books)
                     .set(books.TITLE, "New Title")

    result = query.to_sql

    assert_that(result.sql).equals("UPDATE books SET title = $1")
    assert_that(result.params).equals(["New Title"])
  end

  def test_supports_multiple_set_clauses
    query = Rooq::DSL.update(books)
                     .set(books.TITLE, "New Title")
                     .set(books.AUTHOR_ID, 5)

    result = query.to_sql

    assert_that(result.sql).equals("UPDATE books SET title = $1, author_id = $2")
    assert_that(result.params).equals(["New Title", 5])
  end

  # WHERE clause

  def test_where_adds_condition
    query = Rooq::DSL.update(books)
                     .set(books.TITLE, "New Title")
                     .where(books.ID.eq(1))

    result = query.to_sql

    assert_that(result.sql).equals("UPDATE books SET title = $1 WHERE books.id = $2")
    assert_that(result.params).equals(["New Title", 1])
  end

  # RETURNING clause

  def test_returning_adds_returning_with_specified_fields
    query = Rooq::DSL.update(books)
                     .set(books.TITLE, "New Title")
                     .where(books.ID.eq(1))
                     .returning(books.ID, books.TITLE)

    result = query.to_sql

    assert_that(result.sql).equals("UPDATE books SET title = $1 WHERE books.id = $2 RETURNING books.id, books.title")
  end
end
