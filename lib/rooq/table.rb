# frozen_string_literal: true

module Rooq
  class Table
    attr_reader :name, :fields

    def initialize(name, &block)
      @name = name
      @fields = {}
      @field_accessors = {}

      if block_given?
        builder = TableBuilder.new(self)
        block.call(builder)
      end

      @fields.freeze
      freeze
    end

    def asterisk
      @fields.values
    end

    def method_missing(method_name, *args)
      field_name = method_name.to_s.downcase.to_sym

      if @fields.key?(field_name)
        @fields[field_name]
      else
        available = @fields.keys.join(", ")
        raise ValidationError, "Unknown field '#{field_name}' on table '#{@name}'. Available fields: #{available}"
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      field_name = method_name.to_s.downcase.to_sym
      @fields.key?(field_name) || super
    end

    class TableBuilder
      def initialize(table)
        @table = table
      end

      def field(name, type)
        field = Field.new(name, @table.name, type)
        @table.instance_variable_get(:@fields)[name] = field
      end
    end
  end
end
