# frozen_string_literal: true

module Rooq
  class QueryValidator
    def initialize(tables)
      @tables = tables.each_with_object({}) do |table, hash|
        hash[table.name] = table
      end
    end

    def validate_select(query)
      errors = []

      # Validate FROM table
      if query.from_table
        table_error = validate_table(query.from_table)
        errors << table_error if table_error
      end

      # Validate selected fields
      query.selected_fields.each do |field|
        next unless field.is_a?(Field)

        field_error = validate_field(field)
        errors << field_error if field_error
      end

      # Validate conditions
      if query.conditions
        condition_errors = validate_condition(query.conditions)
        errors.concat(condition_errors)
      end

      # Validate order specs
      query.order_specs.each do |spec|
        field_error = validate_field(spec.field)
        errors << field_error if field_error
      end

      # Validate joins
      query.joins.each do |join|
        table_error = validate_table(join.table)
        errors << table_error if table_error

        condition_errors = validate_condition(join.condition)
        errors.concat(condition_errors)
      end

      raise QueryValidationError.new(errors) unless errors.empty?

      true
    end

    def validate_insert(query)
      errors = []

      table_error = validate_table(query.table)
      errors << table_error if table_error

      query.column_list.each do |field|
        next unless field.is_a?(Field)

        field_error = validate_field(field)
        errors << field_error if field_error
      end

      raise QueryValidationError.new(errors) unless errors.empty?

      true
    end

    def validate_update(query)
      errors = []

      table_error = validate_table(query.table)
      errors << table_error if table_error

      query.set_values.each_key do |field|
        next unless field.is_a?(Field)

        field_error = validate_field(field)
        errors << field_error if field_error
      end

      if query.conditions
        condition_errors = validate_condition(query.conditions)
        errors.concat(condition_errors)
      end

      raise QueryValidationError.new(errors) unless errors.empty?

      true
    end

    def validate_delete(query)
      errors = []

      table_error = validate_table(query.table)
      errors << table_error if table_error

      if query.conditions
        condition_errors = validate_condition(query.conditions)
        errors.concat(condition_errors)
      end

      raise QueryValidationError.new(errors) unless errors.empty?

      true
    end

    private

    def validate_table(table)
      return nil unless table.is_a?(Table)
      return nil if @tables.key?(table.name)

      "Unknown table '#{table.name}'. Known tables: #{@tables.keys.join(', ')}"
    end

    def validate_field(field)
      table = @tables[field.table_name]
      return "Unknown table '#{field.table_name}' for field '#{field.name}'" unless table
      return nil if table.fields.key?(field.name)

      "Unknown field '#{field.name}' on table '#{field.table_name}'. Available: #{table.fields.keys.join(', ')}"
    end

    def validate_condition(condition)
      case condition
      when Condition
        error = validate_field(condition.field)
        error ? [error] : []
      when CombinedCondition
        condition.conditions.flat_map { |c| validate_condition(c) }
      else
        []
      end
    end
  end

  class QueryValidationError < Error
    attr_reader :validation_errors

    def initialize(errors)
      @validation_errors = errors
      super("Query validation failed:\n  - #{errors.join("\n  - ")}")
    end
  end

  class ValidatingExecutor < Executor
    def initialize(connection, tables, dialect: Dialect::PostgreSQL.new)
      super(connection, dialect: dialect)
      @validator = QueryValidator.new(tables)
    end

    def execute(query)
      validate_query(query)
      super
    end

    private

    def validate_query(query)
      case query
      when DSL::SelectQuery
        @validator.validate_select(query)
      when DSL::InsertQuery
        @validator.validate_insert(query)
      when DSL::UpdateQuery
        @validator.validate_update(query)
      when DSL::DeleteQuery
        @validator.validate_delete(query)
      end
    end
  end
end
