# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-21

### Added

- Initial release
- Fluent query builder for SELECT, INSERT, UPDATE, DELETE
- PostgreSQL dialect with parameterized queries
- Schema introspection and code generation
- CLI tool (`rooq generate`) for generating table definitions
- Optional Sorbet type annotations
- Connection management with ConnectionProvider abstraction
- Context API for query execution (similar to jOOQ's DSLContext)
- PostgreSQL connection pool adapter
- Result wrapper with symbol keys and automatic type coercion
- Parameter conversion for Time, Date, Hash, Array types
- Advanced SQL features:
  - JOINs (INNER, LEFT, RIGHT, FULL, CROSS)
  - GROUP BY with HAVING
  - Window functions (ROW_NUMBER, RANK, LAG, LEAD, etc.)
  - Common Table Expressions (CTEs)
  - Set operations (UNION, INTERSECT, EXCEPT)
  - CASE WHEN expressions
  - Aggregate functions
  - Grouping sets (CUBE, ROLLUP)
