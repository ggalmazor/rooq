# frozen_string_literal: true

module Rooq
  class SchemaValidator
    def initialize(connection, schema: "public")
      @introspector = Generator::Introspector.new(connection)
      @schema = schema
    end

    def validate(tables)
      errors = []

      tables.each do |table|
        table_errors = validate_table(table)
        errors.concat(table_errors)
      end

      raise SchemaValidationError.new(errors) unless errors.empty?

      true
    end

    private

    def validate_table(table)
      errors = []

      db_tables = @introspector.introspect_tables(schema: @schema)

      unless db_tables.include?(table.name.to_s)
        errors << "Table '#{table.name}' does not exist in database"
        return errors
      end

      db_columns = @introspector.introspect_columns(table.name.to_s, schema: @schema)
      db_column_names = db_columns.map(&:name)

      table.fields.each_key do |field_name|
        unless db_column_names.include?(field_name.to_s)
          errors << "Column '#{field_name}' on table '#{table.name}' does not exist in database"
        end
      end

      errors
    end
  end

  class SchemaValidationError < Error
    attr_reader :validation_errors

    def initialize(errors)
      @validation_errors = errors
      super("Schema validation failed:\n  - #{errors.join("\n  - ")}")
    end
  end
end
