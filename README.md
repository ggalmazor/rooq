# rOOQ

A Ruby query builder inspired by [jOOQ](https://www.jooq.org/). Build type-safe SQL queries using a fluent, chainable API.

## Features

- **Fluent Query Builder**: Chainable methods for building SELECT, INSERT, UPDATE, and DELETE queries
- **Immutable Queries**: Each builder method returns a new query object
- **Schema Validation**: Generate Ruby code from database schemas with runtime validation
- **PostgreSQL Support**: Full PostgreSQL dialect with parameterized queries
- **Advanced SQL Features**:
  - DISTINCT, GROUP BY, HAVING
  - Window functions (ROW_NUMBER, RANK, LAG, LEAD, etc.)
  - Common Table Expressions (CTEs)
  - Set operations (UNION, INTERSECT, EXCEPT)
  - CASE WHEN expressions
  - Aggregate functions (COUNT, SUM, AVG, MIN, MAX)
  - Grouping sets (CUBE, ROLLUP, GROUPING SETS)
- **CLI Tool**: Generate schema files from the command line
- **Optional Sorbet Types**: Full type annotations with optional generation

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rooq'
```

And then execute:

```bash
bundle install
```

## Quick Start

```ruby
require 'rooq'

# Define a table
books = Rooq::Table.new(:books) do |t|
  t.field :id, :integer
  t.field :title, :string
  t.field :author_id, :integer
  t.field :published_in, :integer
end

# Build a query
query = Rooq::DSL.select(books.TITLE, books.PUBLISHED_IN)
                 .from(books)
                 .where(books.PUBLISHED_IN.gte(2010))
                 .order_by(books.TITLE.asc)
                 .limit(10)

result = query.to_sql
# result.sql => "SELECT books.title, books.published_in FROM books WHERE books.published_in >= $1 ORDER BY books.title ASC LIMIT 10"
# result.params => [2010]
```

## CLI Usage

Generate Ruby table definitions from your PostgreSQL database:

```bash
# Generate schema to stdout
rooq generate -d myapp_development

# Generate schema to file
rooq generate -d myapp_development -o lib/schema.rb

# Generate without Sorbet types
rooq generate -d myapp_development -o lib/schema.rb --no-typed

# See all options
rooq help
```

## Documentation

See [USAGE.md](USAGE.md) for detailed usage examples.

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test
```

## License

The gem is available as open source under the terms of the MIT License.
