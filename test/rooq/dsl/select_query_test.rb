# frozen_string_literal: true

require "test_helper"

class SelectQueryTest < Minitest::Test
  def books
    @books ||= Rooq::Table.new(:books) do |t|
      t.field :id, :integer
      t.field :title, :string
      t.field :author_id, :integer
      t.field :published_in, :integer
    end
  end

  def authors
    @authors ||= Rooq::Table.new(:authors) do |t|
      t.field :id, :integer
      t.field :name, :string
    end
  end

  # basic SELECT

  def test_builds_a_simple_select_query
    query = Rooq::DSL.select(books.TITLE, books.PUBLISHED_IN)
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title, books.published_in FROM books")
    assert_that(result.params).equals([])
  end

  def test_supports_selecting_all_fields_with_asterisk
    query = Rooq::DSL.select(*books.asterisk).from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.id, books.title, books.author_id, books.published_in FROM books")
  end

  # WHERE clause

  def test_where_adds_a_simple_equality_condition
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.PUBLISHED_IN.eq(2011))

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE books.published_in = $1")
    assert_that(result.params).equals([2011])
  end

  def test_where_supports_combined_and_conditions
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.PUBLISHED_IN.gte(2010).and(books.PUBLISHED_IN.lte(2020)))

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE (books.published_in >= $1 AND books.published_in <= $2)")
    assert_that(result.params).equals([2010, 2020])
  end

  def test_where_supports_combined_or_conditions
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.PUBLISHED_IN.eq(2010).or(books.PUBLISHED_IN.eq(2020)))

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE (books.published_in = $1 OR books.published_in = $2)")
    assert_that(result.params).equals([2010, 2020])
  end

  def test_where_supports_in_condition
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.PUBLISHED_IN.in([2010, 2011, 2012]))

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE books.published_in IN ($1, $2, $3)")
    assert_that(result.params).equals([2010, 2011, 2012])
  end

  def test_where_supports_like_condition
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.TITLE.like("%Ruby%"))

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE books.title LIKE $1")
    assert_that(result.params).equals(["%Ruby%"])
  end

  def test_where_supports_between_condition
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.PUBLISHED_IN.between(2010, 2020))

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE books.published_in BETWEEN $1 AND $2")
    assert_that(result.params).equals([2010, 2020])
  end

  def test_where_supports_is_null_condition
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.AUTHOR_ID.is_null)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE books.author_id IS NULL")
    assert_that(result.params).equals([])
  end

  def test_where_supports_is_not_null_condition
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .where(books.AUTHOR_ID.is_not_null)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books WHERE books.author_id IS NOT NULL")
  end

  # ORDER BY clause

  def test_order_by_adds_ascending_order
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .order_by(books.TITLE.asc)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books ORDER BY books.title ASC")
  end

  def test_order_by_adds_descending_order
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .order_by(books.PUBLISHED_IN.desc)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books ORDER BY books.published_in DESC")
  end

  def test_order_by_supports_multiple_order_specifications
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .order_by(books.PUBLISHED_IN.desc, books.TITLE.asc)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books ORDER BY books.published_in DESC, books.title ASC")
  end

  # LIMIT and OFFSET

  def test_limit_adds_limit_clause
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .limit(10)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books LIMIT 10")
  end

  def test_offset_adds_offset_clause
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .offset(20)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books OFFSET 20")
  end

  def test_limit_and_offset_combined
    query = Rooq::DSL.select(books.TITLE)
                     .from(books)
                     .limit(10)
                     .offset(20)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title FROM books LIMIT 10 OFFSET 20")
  end

  # JOINs

  def test_inner_join
    query = Rooq::DSL.select(books.TITLE, authors.NAME)
                     .from(books)
                     .inner_join(authors).on(books.AUTHOR_ID.eq(authors.ID))

    result = query.to_sql

    assert_that(result.sql).starts_with("SELECT books.title, authors.name FROM books INNER JOIN authors ON")
  end

  def test_left_join
    query = Rooq::DSL.select(books.TITLE, authors.NAME)
                     .from(books)
                     .left_join(authors).on(books.AUTHOR_ID.eq(authors.ID))

    result = query.to_sql

    assert_that(result.sql).starts_with("SELECT books.title, authors.name FROM books LEFT JOIN authors ON")
  end

  def test_right_join
    query = Rooq::DSL.select(books.TITLE, authors.NAME)
                     .from(books)
                     .right_join(authors).on(books.AUTHOR_ID.eq(authors.ID))

    result = query.to_sql

    assert_that(result.sql).starts_with("SELECT books.title, authors.name FROM books RIGHT JOIN authors ON")
  end

  # DISTINCT

  def test_distinct_adds_distinct_keyword
    query = Rooq::DSL.select(books.AUTHOR_ID)
                     .from(books)
                     .distinct

    result = query.to_sql

    assert_that(result.sql).equals("SELECT DISTINCT books.author_id FROM books")
  end

  # GROUP BY

  def test_group_by_adds_group_by_clause
    query = Rooq::DSL.select(books.AUTHOR_ID)
                     .from(books)
                     .group_by(books.AUTHOR_ID)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.author_id FROM books GROUP BY books.author_id")
  end

  def test_group_by_supports_multiple_fields
    query = Rooq::DSL.select(books.AUTHOR_ID, books.PUBLISHED_IN)
                     .from(books)
                     .group_by(books.AUTHOR_ID, books.PUBLISHED_IN)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.author_id, books.published_in FROM books GROUP BY books.author_id, books.published_in")
  end

  # HAVING

  def test_having_adds_having_clause
    query = Rooq::DSL.select(books.AUTHOR_ID, Rooq::Aggregates.count(books.ID))
                     .from(books)
                     .group_by(books.AUTHOR_ID)
                     .having(Rooq::Aggregates.count(books.ID).gt(5))

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.author_id, COUNT(books.id) FROM books GROUP BY books.author_id HAVING COUNT(books.id) > $1")
    assert_that(result.params).equals([5])
  end

  # aggregate functions

  def test_count_without_argument_produces_count_star
    query = Rooq::DSL.select(Rooq::Aggregates.count)
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT COUNT(*) FROM books")
  end

  def test_count_with_field_produces_count_field
    query = Rooq::DSL.select(Rooq::Aggregates.count(books.ID))
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT COUNT(books.id) FROM books")
  end

  def test_count_distinct_produces_count_distinct
    query = Rooq::DSL.select(Rooq::Aggregates.count(books.AUTHOR_ID, distinct: true))
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT COUNT(DISTINCT books.author_id) FROM books")
  end

  def test_sum_produces_sum_function
    query = Rooq::DSL.select(Rooq::Aggregates.sum(books.PUBLISHED_IN))
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT SUM(books.published_in) FROM books")
  end

  def test_avg_produces_avg_function
    query = Rooq::DSL.select(Rooq::Aggregates.avg(books.PUBLISHED_IN))
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT AVG(books.published_in) FROM books")
  end

  def test_min_produces_min_function
    query = Rooq::DSL.select(Rooq::Aggregates.min(books.PUBLISHED_IN))
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT MIN(books.published_in) FROM books")
  end

  def test_max_produces_max_function
    query = Rooq::DSL.select(Rooq::Aggregates.max(books.PUBLISHED_IN))
                     .from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT MAX(books.published_in) FROM books")
  end

  # window functions

  def test_row_number_with_order_by
    query = Rooq::DSL.select(
      books.TITLE,
      Rooq::WindowFunctions.row_number
                           .order_by(books.PUBLISHED_IN.desc)
    ).from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title, ROW_NUMBER() OVER (ORDER BY books.published_in DESC) FROM books")
  end

  def test_rank_with_partition_and_order
    query = Rooq::DSL.select(
      books.TITLE,
      Rooq::WindowFunctions.rank
                           .partition_by(books.AUTHOR_ID)
                           .order_by(books.PUBLISHED_IN.desc)
    ).from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title, RANK() OVER (PARTITION BY books.author_id ORDER BY books.published_in DESC) FROM books")
  end

  def test_lag_with_offset
    query = Rooq::DSL.select(
      books.TITLE,
      Rooq::WindowFunctions.lag(books.TITLE, 1)
                           .order_by(books.PUBLISHED_IN.asc)
    ).from(books)

    result = query.to_sql

    assert_that(result.sql).equals("SELECT books.title, LAG(books.title, $1) OVER (ORDER BY books.published_in ASC) FROM books")
    assert_that(result.params).equals([1])
  end

  # CTEs (WITH clause)

  def test_with_adds_cte_to_query
    recent_books = Rooq::DSL.select(books.ID, books.TITLE)
                            .from(books)
                            .where(books.PUBLISHED_IN.gte(2020))

    query = Rooq::DSL.select(Rooq::Literal.new(:*))
                     .from(:recent_books)
                     .with(:recent_books, recent_books)

    result = query.to_sql

    assert_that(result.sql).equals("WITH recent_books AS (SELECT books.id, books.title FROM books WHERE books.published_in >= $1) SELECT * FROM recent_books")
    assert_that(result.params).equals([2020])
  end

  # set operations

  def test_union_combines_two_queries
    query1 = Rooq::DSL.select(books.TITLE)
                      .from(books)
                      .where(books.PUBLISHED_IN.eq(2020))

    query2 = Rooq::DSL.select(books.TITLE)
                      .from(books)
                      .where(books.PUBLISHED_IN.eq(2021))

    result = query1.union(query2).to_sql

    assert_that(result.sql).equals("(SELECT books.title FROM books WHERE books.published_in = $1) UNION (SELECT books.title FROM books WHERE books.published_in = $2)")
    assert_that(result.params).equals([2020, 2021])
  end

  def test_union_all_keeps_duplicates
    query1 = Rooq::DSL.select(books.TITLE).from(books)
    query2 = Rooq::DSL.select(books.TITLE).from(books)

    result = query1.union(query2, all: true).to_sql

    assert_that(result.sql).equals("(SELECT books.title FROM books) UNION ALL (SELECT books.title FROM books)")
  end

  def test_intersect_combines_queries
    query1 = Rooq::DSL.select(books.AUTHOR_ID).from(books)
    query2 = Rooq::DSL.select(authors.ID).from(authors)

    result = query1.intersect(query2).to_sql

    assert_that(result.sql).equals("(SELECT books.author_id FROM books) INTERSECT (SELECT authors.id FROM authors)")
  end

  def test_except_combines_queries
    query1 = Rooq::DSL.select(books.AUTHOR_ID).from(books)
    query2 = Rooq::DSL.select(authors.ID).from(authors)

    result = query1.except(query2).to_sql

    assert_that(result.sql).equals("(SELECT books.author_id FROM books) EXCEPT (SELECT authors.id FROM authors)")
  end

  # immutability

  def test_returns_a_new_query_object_for_each_builder_method
    query1 = Rooq::DSL.select(books.TITLE)
    query2 = query1.from(books)
    query3 = query2.where(books.PUBLISHED_IN.eq(2011))

    refute_same query1, query2
    refute_same query2, query3
  end
end
