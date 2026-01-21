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
- [Executing Queries](#executing-queries)
  - [Getting SQL and Parameters](#getting-sql-and-parameters)
  - [Using Context](#using-context-recommended)
  - [Using Executor](#using-executor-low-level)
- [Type Handling](#type-handling)
  - [Result Type Coercion](#result-type-coercion)
  - [Parameter Type Conversion](#parameter-type-conversion)
- [Query Validation](#query-validation-development-mode)
- [Code Generation](#code-generation)
- [Immutability](#immutability)

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

### Getting SQL and Parameters

```ruby
# Get SQL and parameters without executing
result = query.to_sql
puts result.sql     # The SQL string with $1, $2, etc.
puts result.params  # Array of parameter values
```

### Using Context (Recommended)

Context is the main entry point for executing queries. It manages connections and provides a clean API for query execution.

#### Single Connection

Use this when you want to manage the connection lifecycle yourself:

```ruby
require "pg"
require "rooq"

# Connect to database
connection = PG.connect(dbname: "myapp_development")

# Create context from connection
ctx = Rooq::Context.using(connection)

# Define tables (or use generated schema)
books = Rooq::Table.new(:books) do |t|
  t.field :id, :integer
  t.field :title, :string
  t.field :author_id, :integer
end

# Execute queries
query = Rooq::DSL.select(books.TITLE, books.AUTHOR_ID)
                 .from(books)
                 .where(books.ID.eq(1))

# Fetch a single row (results use symbol keys)
row = ctx.fetch_one(query)
puts row[:title] if row

# Fetch all rows
rows = ctx.fetch_all(
  Rooq::DSL.select(books.TITLE).from(books).limit(10)
)
rows.each { |r| puts r[:title] }

# Execute without fetching (for INSERT/UPDATE/DELETE)
ctx.execute(
  Rooq::DSL.insert_into(books)
           .columns(:title, :author_id)
           .values("New Book", 1)
)

# Don't forget to close when done
connection.close
```

#### Connection Pool

Use this for applications that need to handle multiple concurrent requests:

```ruby
require "pg"
require "rooq"

# Create a connection pool
pool = Rooq::Adapters::PostgreSQL::ConnectionPool.new(size: 10, timeout: 5) do
  PG.connect(
    dbname: "myapp_production",
    host: "localhost",
    user: "postgres",
    password: "secret"
  )
end

# Create context from pool
ctx = Rooq::Context.using_pool(pool)

# Connections are automatically acquired and released per query
books = Schema::BOOKS  # Assuming generated schema
rows = ctx.fetch_all(
  Rooq::DSL.select(books.TITLE).from(books)
)

# Each query gets its own connection from the pool
# Multiple threads can safely use the same context
Thread.new do
  ctx.fetch_all(Rooq::DSL.select(books.ID).from(books))
end

# Shutdown pool when application exits
pool.shutdown
```

#### Transactions

```ruby
ctx = Rooq::Context.using(connection)

# Transaction commits on success, rolls back on error
ctx.transaction do
  ctx.execute(
    Rooq::DSL.insert_into(books)
             .columns(:title, :author_id)
             .values("Book 1", 1)
  )

  ctx.execute(
    Rooq::DSL.update(authors)
             .set(:book_count, Rooq::Literal.new("book_count + 1"))
             .where(authors.ID.eq(1))
  )
end

# If any query fails, all changes are rolled back
begin
  ctx.transaction do
    ctx.execute(Rooq::DSL.insert_into(books).columns(:title).values("Book"))
    raise "Something went wrong!"  # This triggers rollback
  end
rescue RuntimeError
  puts "Transaction was rolled back"
end
```

#### With RETURNING Clause

```ruby
# INSERT with RETURNING
query = Rooq::DSL.insert_into(books)
                 .columns(:title, :author_id)
                 .values("New Book", 1)
                 .returning(books.ID, books.TITLE)

result = ctx.fetch_one(query)
puts "Created book ##{result['id']}: #{result['title']}"

# UPDATE with RETURNING
query = Rooq::DSL.update(books)
                 .set(:title, "Updated Title")
                 .where(books.ID.eq(1))
                 .returning(books.ID, books.TITLE)

result = ctx.fetch_one(query)
puts "Updated: #{result['title']}"

# DELETE with RETURNING
query = Rooq::DSL.delete_from(books)
                 .where(books.ID.eq(1))
                 .returning(books.ID, books.TITLE)

deleted = ctx.fetch_one(query)
puts "Deleted: #{deleted['title']}" if deleted
```

### Using Executor (Low-level)

For more control over execution, use the Executor class directly:

```ruby
executor = Rooq::Executor.new(pg_connection)

# Execute and get raw PG::Result
result = executor.execute(query)

# Fetch helpers
row = executor.fetch_one(query)      # Single row or nil
rows = executor.fetch_all(query)     # Array of rows

# Lifecycle hooks
executor.on_before_execute do |rendered|
  puts "SQL: #{rendered.sql}"
  puts "Params: #{rendered.params}"
end

executor.on_after_execute do |rendered, result|
  puts "Returned #{result.ntuples} rows"
end
```

## Type Handling

### Result Type Coercion

Results automatically convert PostgreSQL types to Ruby types:

```ruby
# Results use symbol keys
row = ctx.fetch_one(query)
row[:title]      # String
row[:id]         # Integer (not string)
row[:created_at] # Time object
row[:birth_date] # Date object
row[:tags]       # Array (from PostgreSQL array)
row[:metadata]   # Hash (from JSON/JSONB)
row[:settings]   # Hash (from JSONB)
```

Supported conversions:
- `json`, `jsonb` → Ruby Hash or Array
- `integer[]`, `bigint[]` → Array of integers
- `text[]`, `varchar[]` → Array of strings
- `timestamp`, `timestamptz` → Time
- `date` → Date
- `boolean` → true/false
- `integer`, `bigint`, `smallint` → Integer
- `real`, `double precision`, `numeric` → Float

### Parameter Type Conversion

Parameters are automatically converted when executing queries:

```ruby
# Time/Date parameters
created_after = Time.now - 86400  # 24 hours ago
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(books.CREATED_AT.gte(created_after))
ctx.fetch_all(query)  # Time converted to ISO 8601

# Hash parameters (converted to JSON)
metadata = { tags: ["ruby", "sql"], priority: "high" }
query = Rooq::DSL.insert_into(books)
                 .columns(:title, :metadata)
                 .values("My Book", metadata)
ctx.execute(query)  # Hash converted to JSON string

# Array parameters (for array columns)
tags = ["programming", "ruby"]
query = Rooq::DSL.insert_into(books)
                 .columns(:title, :tags)
                 .values("Ruby Guide", tags)
ctx.execute(query)  # Array converted to PostgreSQL array literal

# Date parameters
published = Date.new(2024, 1, 15)
query = Rooq::DSL.select(books.TITLE)
                 .from(books)
                 .where(books.PUBLISHED_DATE.eq(published))
ctx.fetch_all(query)  # Date converted to ISO 8601
```

Supported parameter conversions:
- `Time`, `DateTime` → ISO 8601 string
- `Date` → ISO 8601 date string
- `Hash` → JSON string
- `Array` of primitives → PostgreSQL array literal (`{1,2,3}`)
- `Array` of hashes → JSON array string
- `Symbol` → String

## Query Validation (Development Mode)

```ruby
# Create a validating executor for development
validator = Rooq::QueryValidator.new(schema)
executor = Rooq::ValidatingExecutor.new(pg_connection, validator)

# Queries are validated against the schema before execution
executor.execute(query)  # Raises ValidationError if query references invalid tables/columns
```

## Code Generation

Generate Ruby table definitions from your PostgreSQL database schema.

### Using the CLI (Recommended)

```bash
# Generate schema to lib/schema.rb (default)
rooq generate -d myapp_development

# Generate with custom namespace (writes to lib/my_app/db.rb)
rooq generate -d myapp_development -n MyApp::DB

# Generate to custom file
rooq generate -d myapp_development -o db/schema.rb

# Generate without Sorbet types
rooq generate -d myapp_development --no-typed

# Print to stdout instead of file
rooq generate -d myapp_development --stdout

# Full connection options
rooq generate -d myapp -h localhost -p 5432 -U postgres -W secret -s public
```

### Using Ruby API

```ruby
require "pg"
require "rooq"

# Connect to database
connection = PG.connect(dbname: "myapp_development")

# Introspect schema
introspector = Rooq::Generator::Introspector.new(connection)
schema_info = introspector.introspect_schema(schema: "public")

# Generate code with Sorbet types and custom namespace
generator = Rooq::Generator::CodeGenerator.new(schema_info, namespace: "MyApp::DB")
puts generator.generate

# Generate code without Sorbet types
generator = Rooq::Generator::CodeGenerator.new(schema_info, typed: false)
puts generator.generate
```

### Generated Code with Sorbet Types

```ruby
# typed: strict
# frozen_string_literal: true

require "rooq"
require "sorbet-runtime"

module MyApp::DB
  extend T::Sig

  USERS = T.let(Rooq::Table.new(:users) do |t|
    t.field :id, :integer
    t.field :name, :string
    t.field :email, :string
  end, Rooq::Table)

  USER_ACCOUNTS = T.let(Rooq::Table.new(:user_accounts) do |t|
    t.field :id, :integer
    t.field :user_id, :integer
    t.field :account_type, :string
  end, Rooq::Table)
end
```

### Generated Code without Sorbet Types

```ruby
# frozen_string_literal: true

require "rooq"

module Schema
  USERS = Rooq::Table.new(:users) do |t|
    t.field :id, :integer
    t.field :name, :string
    t.field :email, :string
  end
end
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
