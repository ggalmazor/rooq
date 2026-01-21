# frozen_string_literal: true

require "test_helper"

class DeleteQueryTest < Minitest::Test
  def books
    @books ||= Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
    end
  end

  # basic DELETE

  def test_builds_a_simple_delete_query
    query = Rooq::DSL.delete_from(books)

    result = query.to_sql

    assert_that(result.sql).equals("DELETE FROM books")
    assert_that(result.params).equals([])
  end

  # WHERE clause

  def test_where_adds_condition
    query = Rooq::DSL.delete_from(books)
                     .where(books.ID.eq(1))

    result = query.to_sql

    assert_that(result.sql).equals("DELETE FROM books WHERE books.id = $1")
    assert_that(result.params).equals([1])
  end

  def test_where_supports_complex_conditions
    query = Rooq::DSL.delete_from(books)
                     .where(books.ID.gt(10).and(books.TITLE.like("%old%")))

    result = query.to_sql

    assert_that(result.sql).equals("DELETE FROM books WHERE (books.id > $1 AND books.title LIKE $2)")
    assert_that(result.params).equals([10, "%old%"])
  end

  # RETURNING clause

  def test_returning_adds_returning_with_specified_fields
    query = Rooq::DSL.delete_from(books)
                     .where(books.ID.eq(1))
                     .returning(books.ID, books.TITLE)

    result = query.to_sql

    assert_that(result.sql).equals("DELETE FROM books WHERE books.id = $1 RETURNING books.id, books.title")
  end
end
