# frozen_string_literal: true

require "test_helper"
require "time"
require "date"

class ParameterConverterTest < Minitest::Test
  def setup
    @converter = Rooq::ParameterConverter.new
  end

  # Passthrough for basic types

  def test_string_passes_through
    assert_that(@converter.convert("hello")).equals("hello")
  end

  def test_integer_passes_through
    assert_that(@converter.convert(42)).equals(42)
  end

  def test_float_passes_through
    assert_that(@converter.convert(3.14)).equals(3.14)
  end

  def test_nil_passes_through
    assert_nil @converter.convert(nil)
  end

  def test_true_passes_through
    assert_that(@converter.convert(true)).equals(true)
  end

  def test_false_passes_through
    assert_that(@converter.convert(false)).equals(false)
  end

  # Time conversion

  def test_time_converts_to_iso8601
    time = Time.new(2024, 1, 15, 10, 30, 45, "+00:00")

    result = @converter.convert(time)

    assert result.include?("2024-01-15")
    assert result.include?("10:30:45")
  end

  def test_time_with_timezone
    time = Time.new(2024, 6, 20, 14, 0, 0, "-05:00")

    result = @converter.convert(time)

    assert_that(result).descends_from(String)
  end

  # Date conversion

  def test_date_converts_to_iso8601
    date = Date.new(2024, 1, 15)

    result = @converter.convert(date)

    assert_that(result).equals("2024-01-15")
  end

  # DateTime conversion

  def test_datetime_converts_to_iso8601
    datetime = DateTime.new(2024, 1, 15, 10, 30, 45)

    result = @converter.convert(datetime)

    assert result.include?("2024-01-15")
  end

  # Hash to JSON

  def test_hash_converts_to_json
    hash = { name: "test", count: 42 }

    result = @converter.convert(hash)

    assert_that(result).equals('{"name":"test","count":42}')
  end

  def test_nested_hash_converts_to_json
    hash = { user: { name: "John", age: 30 }, active: true }

    result = @converter.convert(hash)

    parsed = JSON.parse(result)
    assert_that(parsed["user"]["name"]).equals("John")
    assert_that(parsed["active"]).equals(true)
  end

  def test_hash_with_string_keys_converts_to_json
    hash = { "name" => "test" }

    result = @converter.convert(hash)

    assert_that(result).equals('{"name":"test"}')
  end

  # Array conversion

  def test_integer_array_converts_to_pg_array
    array = [1, 2, 3]

    result = @converter.convert(array)

    assert_that(result).equals("{1,2,3}")
  end

  def test_string_array_converts_to_pg_array
    array = ["ruby", "python", "go"]

    result = @converter.convert(array)

    assert_that(result).equals("{ruby,python,go}")
  end

  def test_string_array_with_spaces_quotes_elements
    array = ["hello world", "foo bar"]

    result = @converter.convert(array)

    assert_that(result).equals('{"hello world","foo bar"}')
  end

  def test_string_array_with_commas_quotes_elements
    array = ["a,b", "c,d"]

    result = @converter.convert(array)

    assert_that(result).equals('{"a,b","c,d"}')
  end

  def test_empty_array_converts_to_empty_pg_array
    result = @converter.convert([])

    assert_that(result).equals("{}")
  end

  def test_array_with_nil_converts_null
    array = [1, nil, 3]

    result = @converter.convert(array)

    assert_that(result).equals("{1,NULL,3}")
  end

  def test_nested_array_of_hashes_converts_to_json
    array = [{ a: 1 }, { b: 2 }]

    result = @converter.convert(array)

    # Arrays of hashes should be JSON, not PG array
    assert_that(result).equals('[{"a":1},{"b":2}]')
  end

  # Symbol conversion

  def test_symbol_converts_to_string
    assert_that(@converter.convert(:active)).equals("active")
  end

  # Integration: multiple params

  def test_convert_all_converts_array_of_params
    params = [42, "hello", Time.new(2024, 1, 15), { key: "value" }]

    results = @converter.convert_all(params)

    assert_that(results[0]).equals(42)
    assert_that(results[1]).equals("hello")
    assert results[2].include?("2024-01-15")
    assert_that(results[3]).equals('{"key":"value"}')
  end
end
