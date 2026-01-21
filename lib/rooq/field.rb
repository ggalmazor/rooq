# frozen_string_literal: true

module Rooq
  class OrderSpecification
    attr_reader :expression, :direction, :nulls

    def initialize(expression, direction, nulls: nil)
      @expression = expression
      @direction = direction
      @nulls = nulls
      freeze
    end

    def nulls_first
      OrderSpecification.new(@expression, @direction, nulls: :first)
    end

    def nulls_last
      OrderSpecification.new(@expression, @direction, nulls: :last)
    end

    # For backwards compatibility
    def field
      @expression
    end
  end

  class Field < Expression
    attr_reader :name, :table_name, :type

    def initialize(name, table_name, type)
      @name = name
      @table_name = table_name
      @type = type
      freeze
    end

    def qualified_name
      "#{table_name}.#{name}"
    end
  end
end
