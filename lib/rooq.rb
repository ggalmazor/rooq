# frozen_string_literal: true

require_relative "rooq/version"
require_relative "rooq/field"
require_relative "rooq/table"
require_relative "rooq/condition"
require_relative "rooq/dsl"
require_relative "rooq/dialect"
require_relative "rooq/generator"

module Rooq
  class Error < StandardError; end
  class SchemaError < Error; end
  class ValidationError < Error; end
end
