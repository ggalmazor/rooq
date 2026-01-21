# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Rooq
  class Table
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :name

    sig { returns(T::Hash[Symbol, Field]) }
    attr_reader :fields

    sig { params(name: Symbol, block: T.nilable(T.proc.params(builder: TableBuilder).void)).void }
    def initialize(name, &block)
      @name = name
      @fields = T.let({}, T::Hash[Symbol, Field])
      @field_accessors = T.let({}, T::Hash[Symbol, Field])

      if block_given?
        builder = TableBuilder.new(self)
        block.call(builder)
      end

      @fields.freeze
      freeze
    end

    sig { returns(T::Array[Field]) }
    def asterisk
      @fields.values
    end

    sig { params(method_name: Symbol, args: T.untyped).returns(Field) }
    def method_missing(method_name, *args)
      field_name = method_name.to_s.downcase.to_sym

      if @fields.key?(field_name)
        T.must(@fields[field_name])
      else
        available = @fields.keys.join(", ")
        raise ValidationError, "Unknown field '#{field_name}' on table '#{@name}'. Available fields: #{available}"
      end
    end

    sig { params(method_name: Symbol, include_private: T::Boolean).returns(T::Boolean) }
    def respond_to_missing?(method_name, include_private = false)
      field_name = method_name.to_s.downcase.to_sym
      @fields.key?(field_name) || super
    end

    class TableBuilder
      extend T::Sig

      sig { params(table: Table).void }
      def initialize(table)
        @table = table
      end

      sig { params(name: Symbol, type: Symbol).returns(Field) }
      def field(name, type)
        field = Field.new(name, @table.name, type)
        @table.instance_variable_get(:@fields)[name] = field
      end
    end
  end
end
