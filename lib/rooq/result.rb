# frozen_string_literal: true

require "json"
require "time"
require "date"

module Rooq
  # Result wraps a database result set and provides:
  # - Symbol keys instead of string keys
  # - Automatic type coercion for JSON, JSONB, ARRAY, timestamps, dates
  # - Enumerable interface
  #
  # @example
  #   result = ctx.fetch_all(query)
  #   result.each do |row|
  #     puts row[:title]        # Symbol key access
  #     puts row[:tags].first   # Array is parsed
  #     puts row[:metadata]     # JSON is parsed to Hash
  #   end
  class Result
    include Enumerable

    attr_reader :raw_result

    # @param raw_result [PG::Result] the raw database result
    # @param coercer [TypeCoercer] optional custom type coercer
    def initialize(raw_result, coercer: TypeCoercer.new)
      @raw_result = raw_result
      @coercer = coercer
      @field_info = build_field_info
      @rows = nil
    end

    # @yield [Hash] each row with symbol keys
    def each(&block)
      rows.each(&block)
    end

    # @return [Hash, nil] the first row or nil
    def first
      rows.first
    end

    # @return [Array<Hash>] all rows
    def to_a
      rows.dup
    end

    # @return [Boolean] true if no rows
    def empty?
      size.zero?
    end

    # @return [Integer] number of rows
    def size
      @raw_result.ntuples
    end
    alias length size
    alias count size

    private

    def rows
      @rows ||= build_rows
    end

    def build_rows
      result = []
      @raw_result.ntuples.times do |row_index|
        result << build_row(row_index)
      end
      result
    end

    def build_row(row_index)
      row = {}
      @field_info.each_with_index do |(name, oid), col_index|
        value = @raw_result.getvalue(row_index, col_index)
        row[name] = @coercer.coerce(value, oid)
      end
      row
    end

    def build_field_info
      info = []
      @raw_result.nfields.times do |i|
        name = @raw_result.fname(i).to_sym
        oid = @raw_result.ftype(i)
        info << [name, oid]
      end
      info
    end
  end

  # TypeCoercer converts PostgreSQL values to Ruby types based on OID.
  class TypeCoercer
    # PostgreSQL type OIDs
    OID_BOOL = 16
    OID_INT2 = 21
    OID_INT4 = 23
    OID_INT8 = 20
    OID_FLOAT4 = 700
    OID_FLOAT8 = 701
    OID_NUMERIC = 1700
    OID_TEXT = 25
    OID_VARCHAR = 1043
    OID_DATE = 1082
    OID_TIMESTAMP = 1114
    OID_TIMESTAMPTZ = 1184
    OID_JSON = 114
    OID_JSONB = 3802
    OID_INT4_ARRAY = 1007
    OID_INT8_ARRAY = 1016
    OID_TEXT_ARRAY = 1009
    OID_VARCHAR_ARRAY = 1015
    OID_FLOAT4_ARRAY = 1021
    OID_FLOAT8_ARRAY = 1022
    OID_BOOL_ARRAY = 1000
    OID_UUID = 2950

    # Coerce a value based on its PostgreSQL OID.
    # @param value [String, nil] the raw value from the database
    # @param oid [Integer] the PostgreSQL type OID
    # @return [Object] the coerced value
    def coerce(value, oid)
      return nil if value.nil?

      case oid
      when OID_JSON, OID_JSONB
        coerce_json(value)
      when OID_INT4_ARRAY, OID_INT8_ARRAY
        coerce_int_array(value)
      when OID_TEXT_ARRAY, OID_VARCHAR_ARRAY
        coerce_text_array(value)
      when OID_FLOAT4_ARRAY, OID_FLOAT8_ARRAY
        coerce_float_array(value)
      when OID_BOOL_ARRAY
        coerce_bool_array(value)
      when OID_TIMESTAMP, OID_TIMESTAMPTZ
        coerce_timestamp(value)
      when OID_DATE
        coerce_date(value)
      when OID_BOOL
        coerce_bool(value)
      when OID_INT2, OID_INT4, OID_INT8
        coerce_integer(value)
      when OID_FLOAT4, OID_FLOAT8, OID_NUMERIC
        coerce_float(value)
      else
        value
      end
    end

    private

    def coerce_json(value)
      JSON.parse(value)
    rescue JSON::ParserError
      value
    end

    def coerce_int_array(value)
      parse_pg_array(value).map { |v| v&.to_i }
    end

    def coerce_text_array(value)
      parse_pg_array(value)
    end

    def coerce_float_array(value)
      parse_pg_array(value).map { |v| v&.to_f }
    end

    def coerce_bool_array(value)
      parse_pg_array(value).map { |v| coerce_bool(v) }
    end

    def coerce_timestamp(value)
      Time.parse(value)
    rescue ArgumentError
      value
    end

    def coerce_date(value)
      Date.parse(value)
    rescue ArgumentError
      value
    end

    def coerce_bool(value)
      return nil if value.nil?
      return value if value == true || value == false

      value == "t" || value == "true" || value == "1"
    end

    def coerce_integer(value)
      return value if value.is_a?(Integer)

      value.to_i
    end

    def coerce_float(value)
      return value if value.is_a?(Float)

      value.to_f
    end

    # Parse PostgreSQL array literal format: {val1,val2,val3}
    def parse_pg_array(value)
      return [] if value == "{}"

      # Remove outer braces
      inner = value[1..-2]
      return [] if inner.nil? || inner.empty?

      elements = []
      current = ""
      in_quotes = false
      escape_next = false

      inner.each_char do |char|
        if escape_next
          current += char
          escape_next = false
        elsif char == '\\'
          escape_next = true
        elsif char == '"'
          in_quotes = !in_quotes
        elsif char == ',' && !in_quotes
          elements << parse_array_element(current)
          current = ""
        else
          current += char
        end
      end

      elements << parse_array_element(current) unless current.empty?
      elements
    end

    def parse_array_element(str)
      return nil if str == "NULL"

      str
    end
  end
end
