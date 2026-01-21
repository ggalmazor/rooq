# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Setup

This is a Ruby project using Ruby 4.0.1 (managed via asdf/.tool-versions).

## Development Approach

- **Strict TDD**: Write tests first, then implement code to make them pass
- **Grey-box testing**: Unit tests have knowledge of internal structure while testing through public interfaces
- **Commit discipline**: Only commit after all tests pass. Commit every small, coherent change immediately after tests are green

## Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rake test

# Run a single test file
bundle exec ruby -Ilib:test test/path/to/file_test.rb

# Run a specific test by name
bundle exec ruby -Ilib:test test/path/to/file_test.rb -n test_method_name
```

## Testing

Uses minitest and minicrest gems.

### Test Style Requirements

- **Use `assert_that` exclusively**: Always use minicrest's `assert_that` with matchers, never plain minitest assertions
- **Descriptive test names**: Use comments to group related tests and descriptive method names

```ruby
class BookTest < Minitest::Test
  # initialization

  def test_stores_title
    book = Book.new(title: "Ruby")
    assert_that(book.title).equals("Ruby")
  end

  def test_validates_presence_of_title
    error = assert_raises(ValidationError) { Book.new(title: nil) }
    assert_that(error.message).matches_pattern(/title is required/)
  end
end
```
