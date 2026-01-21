# rOOQ Usage Guide

## Table of Contents

- [Defining Tables](#defining-tables)
- [SELECT Queries](#select-queries)
- [WHERE Conditions](#where-conditions)
- [JOINs](#joins)
- [GROUP BY and HAVING](#group-by-and-having)
- [Aggregate Functions](#aggregate-functions)
- [Window Functions](#window-functions)
- [Common Table Expressions (CTEs)](#common-table-expressions-ctes)
- [Set Operations](#set-operations)
- [CASE WHEN Expressions](#case-when-expressions)
- [INSERT Queries](#insert-queries)
- [UPDATE Queries](#update-queries)
- [DELETE Queries](#delete-queries)
- [Subqueries](#subqueries)

## Defining Tables

```ruby
books = Rooq::Table.new(:books) do |t|
  t.field :id, :integer
  t.field :title, :string
  t.field :author_id, :integer
  t.field :published_in, :integer
  t.field :price, :decimal
end

authors = Rooq::Table.new(:authors) do |t|
  t.field :id, :integer
  t.field :name, :string
end
```

## SELECT Queries

### Basic SELECT

```ruby
# Select specific columns
query = Rooq::DSL.select(books.TITLE, books.PUBLISHED_IN)
                 .from(books)

# Select all columns
query = Rooq::DSL.select(*books.asterisk)
                 .from(books)

# DISTINCT
query = Rooq::DSL.select(books.AUTHOR_ID)
                 .from(books)
                 .distinct
```

### Column Aliases

```ruby
query = Rooq::DSL.select(
  books.TITLE.as(:book_title),
  books.PUBLISHED_IN.as(:year)
).from(books)
```

### Ordering

```ruby
# Simple ordering
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .order_by(books.TITLE.asc)

# Multiple columns
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .order_by(books.PUBLISHED_IN.desc, books.TITLE.asc)

# NULLS FIRST/LAST
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .order_by(books.AUTHOR_ID.asc.nulls_last)
```

### LIMIT and OFFSET

```ruby
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .limit(10)
                 .offset(20)
```

### FOR UPDATE (Row Locking)

```ruby
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(books.ID.eq(1))
                 .for_update
```

## WHERE Conditions

### Comparison Operators

```ruby
# Equality
.where(books.ID.eq(1))

# Not equal
.where(books.ID.ne(1))

# Greater than / Less than
.where(books.PUBLISHED_IN.gt(2010))
.where(books.PUBLISHED_IN.lt(2020))

# Greater/less than or equal
.where(books.PUBLISHED_IN.gte(2010))
.where(books.PUBLISHED_IN.lte(2020))

# NULL checks
.where(books.AUTHOR_ID.is_null)
.where(books.AUTHOR_ID.is_not_null)

# Also handles nil values automatically
.where(books.AUTHOR_ID.eq(nil))  # IS NULL
.where(books.AUTHOR_ID.ne(nil))  # IS NOT NULL
```

### IN / LIKE / BETWEEN

```ruby
# IN
.where(books.PUBLISHED_IN.in([2010, 2011, 2012]))

# LIKE
.where(books.TITLE.like("%Ruby%"))

# ILIKE (case-insensitive, PostgreSQL)
.where(books.TITLE.ilike("%ruby%"))

# BETWEEN
.where(books.PUBLISHED_IN.between(2010, 2020))
```

### Combining Conditions

```ruby
# AND
.where(books.PUBLISHED_IN.gte(2010).and(books.PUBLISHED_IN.lte(2020)))

# OR
.where(books.PUBLISHED_IN.eq(2010).or(books.PUBLISHED_IN.eq(2020)))

# Chaining where adds AND
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(books.PUBLISHED_IN.gte(2010))
                 .and_where(books.AUTHOR_ID.eq(1))

# or_where for OR conditions
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(books.PUBLISHED_IN.eq(2010))
                 .or_where(books.PUBLISHED_IN.eq(2020))
```

## JOINs

### INNER JOIN

```ruby
query = Rooq::DSL.select(books.TITLE, authors.NAME)
                 .from(books)
                 .inner_join(authors).on(books.AUTHOR_ID.eq(authors.ID))
```

### LEFT/RIGHT/FULL JOIN

```ruby
# LEFT JOIN
.left_join(authors).on(books.AUTHOR_ID.eq(authors.ID))

# RIGHT JOIN
.right_join(authors).on(books.AUTHOR_ID.eq(authors.ID))

# FULL JOIN
.full_join(authors).on(books.AUTHOR_ID.eq(authors.ID))

# CROSS JOIN
.cross_join(categories)
```

### USING Clause

```ruby
.inner_join(authors).using(:author_id)
```

### Table Aliases

```ruby
query = Rooq::DSL.select(books.TITLE)
                 .from(books, as: :b)
                 .inner_join(authors, as: :a).on(books.AUTHOR_ID.eq(authors.ID))
```

## GROUP BY and HAVING

```ruby
query = Rooq::DSL.select(
  books.AUTHOR_ID,
  Rooq::Aggregates.count(books.ID).as(:book_count)
)
.from(books)
.group_by(books.AUTHOR_ID)
.having(Rooq::Aggregates.count(books.ID).gt(5))
```

### Advanced Grouping

```ruby
# GROUPING SETS
.group_by(Rooq::DSL::GroupingSets.new(
  [books.AUTHOR_ID],
  [books.PUBLISHED_IN],
  []
))

# CUBE
.group_by(Rooq::DSL::Cube.new(books.AUTHOR_ID, books.PUBLISHED_IN))

# ROLLUP
.group_by(Rooq::DSL::Rollup.new(books.AUTHOR_ID, books.PUBLISHED_IN))
```

## Aggregate Functions

```ruby
# COUNT
Rooq::Aggregates.count                           # COUNT(*)
Rooq::Aggregates.count(books.ID)                 # COUNT(books.id)
Rooq::Aggregates.count(books.AUTHOR_ID, distinct: true)  # COUNT(DISTINCT books.author_id)

# SUM, AVG, MIN, MAX
Rooq::Aggregates.sum(books.PRICE)
Rooq::Aggregates.avg(books.PRICE)
Rooq::Aggregates.min(books.PUBLISHED_IN)
Rooq::Aggregates.max(books.PUBLISHED_IN)

# STRING_AGG (PostgreSQL)
Rooq::Aggregates.string_agg(books.TITLE, ', ')

# ARRAY_AGG (PostgreSQL)
Rooq::Aggregates.array_agg(books.TITLE)
```

## Window Functions

```ruby
# ROW_NUMBER
Rooq::WindowFunctions.row_number
  .partition_by(books.AUTHOR_ID)
  .order_by(books.PUBLISHED_IN.desc)
  .as(:row_num)

# RANK / DENSE_RANK
Rooq::WindowFunctions.rank
  .order_by(books.PRICE.desc)

Rooq::WindowFunctions.dense_rank
  .partition_by(books.AUTHOR_ID)
  .order_by(books.PRICE.desc)

# LAG / LEAD
Rooq::WindowFunctions.lag(books.PRICE, 1)
  .partition_by(books.AUTHOR_ID)
  .order_by(books.PUBLISHED_IN.asc)

Rooq::WindowFunctions.lead(books.PRICE, 1, 0)
  .partition_by(books.AUTHOR_ID)
  .order_by(books.PUBLISHED_IN.asc)

# FIRST_VALUE / LAST_VALUE
Rooq::WindowFunctions.first_value(books.TITLE)
  .partition_by(books.AUTHOR_ID)
  .order_by(books.PUBLISHED_IN.asc)

# NTH_VALUE
Rooq::WindowFunctions.nth_value(books.TITLE, 2)
  .partition_by(books.AUTHOR_ID)
  .order_by(books.PUBLISHED_IN.asc)

# NTILE
Rooq::WindowFunctions.ntile(4)
  .order_by(books.PRICE.desc)
```

### Window Frame Specifications

```ruby
Rooq::WindowFunctions.sum(books.PRICE)
  .partition_by(books.AUTHOR_ID)
  .order_by(books.PUBLISHED_IN.asc)
  .rows_between(:unbounded_preceding, :current_row)

# Other frame options:
.rows(:unbounded_preceding)
.rows(:current_row)
.rows_between(:current_row, :unbounded_following)
.rows_between([:preceding, 3], [:following, 3])

# RANGE frames
.range_between(:unbounded_preceding, :current_row)
```

## Common Table Expressions (CTEs)

```ruby
# Simple CTE
recent_books = Rooq::DSL.select(books.ID, books.TITLE)
                        .from(books)
                        .where(books.PUBLISHED_IN.gte(2020))

query = Rooq::DSL.select(Rooq::Literal.new(:*))
                 .from(:recent_books)
                 .with(:recent_books, recent_books)

# Recursive CTE
base_query = Rooq::DSL.select(categories.ID, categories.NAME, categories.PARENT_ID)
                      .from(categories)
                      .where(categories.PARENT_ID.is_null)

recursive_query = Rooq::DSL.select(categories.ID, categories.NAME, categories.PARENT_ID)
                           .from(categories)
                           .inner_join(:category_tree)
                           .on(categories.PARENT_ID.eq(Rooq::Field.new(:id, :category_tree, :integer)))

query = Rooq::DSL.select(Rooq::Literal.new(:*))
                 .from(:category_tree)
                 .with(:category_tree, base_query.union(recursive_query), recursive: true)
```

## Set Operations

```ruby
# UNION (removes duplicates)
query1.union(query2)

# UNION ALL (keeps duplicates)
query1.union(query2, all: true)

# INTERSECT
query1.intersect(query2)

# EXCEPT
query1.except(query2)

# Chaining and ordering
query1.union(query2)
      .union(query3)
      .order_by(books.TITLE.asc)
      .limit(10)
```

## CASE WHEN Expressions

```ruby
price_category = Rooq::CaseExpression.new
  .when(books.PRICE.lt(10), Rooq::Literal.new("cheap"))
  .when(books.PRICE.lt(50), Rooq::Literal.new("moderate"))
  .else(Rooq::Literal.new("expensive"))
  .as(:price_category)

query = Rooq::DSL.select(books.TITLE, price_category)
                 .from(books)
```

## INSERT Queries

```ruby
# Single row
query = Rooq::DSL.insert_into(books)
                 .columns(:title, :author_id, :published_in)
                 .values("The Ruby Way", 1, 2023)

# Multiple rows
query = Rooq::DSL.insert_into(books)
                 .columns(:title, :author_id)
                 .values("Book 1", 1)
                 .values("Book 2", 2)

# RETURNING clause
query = Rooq::DSL.insert_into(books)
                 .columns(:title, :author_id)
                 .values("New Book", 1)
                 .returning(books.ID)
```

## UPDATE Queries

```ruby
query = Rooq::DSL.update(books)
                 .set(:title, "Updated Title")
                 .set(:published_in, 2024)
                 .where(books.ID.eq(1))

# RETURNING clause
query = Rooq::DSL.update(books)
                 .set(:price, 29.99)
                 .where(books.ID.eq(1))
                 .returning(books.ID, books.PRICE)
```

## DELETE Queries

```ruby
query = Rooq::DSL.delete_from(books)
                 .where(books.ID.eq(1))

# RETURNING clause
query = Rooq::DSL.delete_from(books)
                 .where(books.PUBLISHED_IN.lt(2000))
                 .returning(books.ID, books.TITLE)
```

## Subqueries

### In FROM Clause

```ruby
subquery = Rooq::DSL.select(books.AUTHOR_ID, Rooq::Aggregates.count(books.ID).as(:book_count))
                    .from(books)
                    .group_by(books.AUTHOR_ID)
                    .as_subquery(:author_stats)

query = Rooq::DSL.select(Rooq::Literal.new(:*))
                 .from(subquery)
                 .where(Rooq::Field.new(:book_count, :author_stats, :integer).gt(5))
```

### In WHERE Clause (IN)

```ruby
author_ids = Rooq::DSL.select(authors.ID)
                      .from(authors)
                      .where(authors.NAME.like("%Smith%"))

query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(books.AUTHOR_ID.in(author_ids))
```

### EXISTS / NOT EXISTS

```ruby
subquery = Rooq::DSL.select(Rooq::Literal.new(1))
                    .from(authors)
                    .where(authors.ID.eq(books.AUTHOR_ID))

# EXISTS
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(Rooq.exists(subquery))

# NOT EXISTS
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(Rooq.not_exists(subquery))
```

## Executing Queries

```ruby
# Get SQL and parameters
result = query.to_sql
puts result.sql     # The SQL string with $1, $2, etc.
puts result.params  # Array of parameter values

# Execute with a connection
executor = Rooq::Executor.new(pg_connection)
rows = executor.execute(query)
```

## Query Validation (Development Mode)

```ruby
# Create a validating executor for development
validator = Rooq::QueryValidator.new(schema)
executor = Rooq::ValidatingExecutor.new(pg_connection, validator)

# Queries are validated against the schema before execution
executor.execute(query)  # Raises ValidationError if query references invalid tables/columns
```

## Immutability

All query objects are immutable. Each builder method returns a new query object:

```ruby
query1 = Rooq::DSL.select(books.TITLE).from(books)
query2 = query1.where(books.PUBLISHED_IN.eq(2020))  # query1 is unchanged
query3 = query1.where(books.PUBLISHED_IN.eq(2021))  # Also based on query1

query1.to_sql.sql  # "SELECT books.title FROM books"
query2.to_sql.sql  # "SELECT books.title FROM books WHERE books.published_in = $1"
query3.to_sql.sql  # "SELECT books.title FROM books WHERE books.published_in = $1"
```
