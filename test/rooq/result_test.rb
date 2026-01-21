# frozen_string_literal: true

require "test_helper"
require "json"
require "time"

class ResultTest < Minitest::Test
  # Symbol keys

  def test_row_has_symbol_keys
    raw_result = MockPGResult.new([{ "id" => 1, "title" => "Ruby" }])
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:id]).equals(1)
    assert_that(row[:title]).equals("Ruby")
  end

  def test_row_does_not_have_string_keys
    raw_result = MockPGResult.new([{ "id" => 1 }])
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_nil row["id"]
  end

  # Enumerable

  def test_result_is_enumerable
    raw_result = MockPGResult.new([{ "id" => 1 }, { "id" => 2 }])
    result = Rooq::Result.new(raw_result)

    ids = result.map { |row| row[:id] }

    assert_that(ids).equals([1, 2])
  end

  def test_result_first
    raw_result = MockPGResult.new([{ "id" => 1 }, { "id" => 2 }])
    result = Rooq::Result.new(raw_result)

    assert_that(result.first[:id]).equals(1)
  end

  def test_result_to_a
    raw_result = MockPGResult.new([{ "id" => 1 }, { "id" => 2 }])
    result = Rooq::Result.new(raw_result)

    array = result.to_a

    assert_that(array).has_size(2)
    assert_that(array[0][:id]).equals(1)
  end

  def test_result_empty
    raw_result = MockPGResult.new([])
    result = Rooq::Result.new(raw_result)

    assert result.empty?
  end

  def test_result_size
    raw_result = MockPGResult.new([{ "id" => 1 }, { "id" => 2 }, { "id" => 3 }])
    result = Rooq::Result.new(raw_result)

    assert_that(result.size).equals(3)
  end

  # JSON/JSONB coercion

  def test_json_column_is_parsed
    raw_result = MockPGResult.new(
      [{ "data" => '{"name": "test", "count": 42}' }],
      { "data" => Rooq::TypeCoercer::OID_JSON }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:data]).equals({ "name" => "test", "count" => 42 })
  end

  def test_jsonb_column_is_parsed
    raw_result = MockPGResult.new(
      [{ "data" => '{"active": true}' }],
      { "data" => Rooq::TypeCoercer::OID_JSONB }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:data]).equals({ "active" => true })
  end

  def test_json_array_is_parsed
    raw_result = MockPGResult.new(
      [{ "tags" => '["ruby", "sql"]' }],
      { "tags" => Rooq::TypeCoercer::OID_JSON }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:tags]).equals(["ruby", "sql"])
  end

  def test_null_json_stays_nil
    raw_result = MockPGResult.new(
      [{ "data" => nil }],
      { "data" => Rooq::TypeCoercer::OID_JSON }
    )
    result = Rooq::Result.new(raw_result)

    assert_nil result.first[:data]
  end

  # Array coercion

  def test_integer_array_is_parsed
    raw_result = MockPGResult.new(
      [{ "ids" => "{1,2,3}" }],
      { "ids" => Rooq::TypeCoercer::OID_INT4_ARRAY }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:ids]).equals([1, 2, 3])
  end

  def test_text_array_is_parsed
    raw_result = MockPGResult.new(
      [{ "tags" => "{ruby,python,go}" }],
      { "tags" => Rooq::TypeCoercer::OID_TEXT_ARRAY }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:tags]).equals(["ruby", "python", "go"])
  end

  def test_text_array_with_quotes_is_parsed
    raw_result = MockPGResult.new(
      [{ "names" => '{"hello world","foo bar"}' }],
      { "names" => Rooq::TypeCoercer::OID_TEXT_ARRAY }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:names]).equals(["hello world", "foo bar"])
  end

  def test_empty_array_is_parsed
    raw_result = MockPGResult.new(
      [{ "ids" => "{}" }],
      { "ids" => Rooq::TypeCoercer::OID_INT4_ARRAY }
    )
    result = Rooq::Result.new(raw_result)

    assert_that(result.first[:ids]).equals([])
  end

  def test_null_array_stays_nil
    raw_result = MockPGResult.new(
      [{ "ids" => nil }],
      { "ids" => Rooq::TypeCoercer::OID_INT4_ARRAY }
    )
    result = Rooq::Result.new(raw_result)

    assert_nil result.first[:ids]
  end

  # Timestamp coercion

  def test_timestamp_is_parsed
    raw_result = MockPGResult.new(
      [{ "created_at" => "2024-01-15 10:30:00" }],
      { "created_at" => Rooq::TypeCoercer::OID_TIMESTAMP }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:created_at]).descends_from(Time)
    assert_that(row[:created_at].year).equals(2024)
    assert_that(row[:created_at].month).equals(1)
    assert_that(row[:created_at].day).equals(15)
  end

  def test_timestamptz_is_parsed
    raw_result = MockPGResult.new(
      [{ "created_at" => "2024-01-15 10:30:00+00" }],
      { "created_at" => Rooq::TypeCoercer::OID_TIMESTAMPTZ }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:created_at]).descends_from(Time)
  end

  # Date coercion

  def test_date_is_parsed
    raw_result = MockPGResult.new(
      [{ "birth_date" => "1990-05-20" }],
      { "birth_date" => Rooq::TypeCoercer::OID_DATE }
    )
    result = Rooq::Result.new(raw_result)

    row = result.first

    assert_that(row[:birth_date]).descends_from(Date)
    assert_that(row[:birth_date].year).equals(1990)
    assert_that(row[:birth_date].month).equals(5)
    assert_that(row[:birth_date].day).equals(20)
  end

  private

  class MockPGResult
    def initialize(data, type_oids = {})
      @data = data
      @type_oids = type_oids
      @fields = data.first&.keys || []
    end

    def ntuples
      @data.length
    end

    def nfields
      @fields.length
    end

    def fname(index)
      @fields[index]
    end

    def ftype(index)
      field_name = @fields[index]
      @type_oids[field_name] || 0
    end

    def getvalue(row, col)
      field_name = @fields[col]
      @data[row][field_name]
    end

    def each
      @data.each { |row| yield row }
    end

    def to_a
      @data
    end
  end
end
