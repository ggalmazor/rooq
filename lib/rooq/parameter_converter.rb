# frozen_string_literal: true

require "json"
require "time"
require "date"

module Rooq
  # ParameterConverter converts Ruby objects to PostgreSQL-compatible parameter values.
  #
  # Conversions:
  # - Time/DateTime -> ISO 8601 string
  # - Date -> ISO 8601 date string
  # - Hash -> JSON string
  # - Array of primitives -> PostgreSQL array literal
  # - Array of hashes -> JSON array string
  # - Symbol -> String
  # - Other types pass through unchanged
  #
  # @example
  #   converter = ParameterConverter.new
  #   converter.convert(Time.now)           # => "2024-01-15T10:30:45+00:00"
  #   converter.convert({ key: "value" })   # => '{"key":"value"}'
  #   converter.convert([1, 2, 3])          # => "{1,2,3}"
  class ParameterConverter
    # Convert a single parameter value.
    # @param value [Object] the value to convert
    # @return [Object] the converted value
    def convert(value)
      case value
      when nil, true, false, Integer, Float
        value
      when String
        value
      when Time, DateTime
        value.iso8601
      when Date
        value.iso8601
      when Hash
        JSON.generate(value)
      when Array
        convert_array(value)
      when Symbol
        value.to_s
      else
        value
      end
    end

    # Convert an array of parameter values.
    # @param params [Array] the parameters to convert
    # @return [Array] the converted parameters
    def convert_all(params)
      params.map { |p| convert(p) }
    end

    private

    def convert_array(array)
      return "{}" if array.empty?

      # If array contains hashes, convert to JSON array
      if array.any? { |el| el.is_a?(Hash) }
        return JSON.generate(array)
      end

      # Otherwise convert to PostgreSQL array literal
      elements = array.map { |el| format_pg_array_element(el) }
      "{#{elements.join(',')}}"
    end

    def format_pg_array_element(value)
      return "NULL" if value.nil?

      str = convert(value).to_s

      # Quote if contains special characters
      if needs_quoting?(str)
        "\"#{escape_pg_string(str)}\""
      else
        str
      end
    end

    def needs_quoting?(str)
      str.include?(",") ||
        str.include?(" ") ||
        str.include?('"') ||
        str.include?("\\") ||
        str.include?("{") ||
        str.include?("}") ||
        str.empty?
    end

    def escape_pg_string(str)
      str.gsub('\\', '\\\\').gsub('"', '\\"')
    end
  end
end
