# frozen_string_literal: true

module Rooq
  class OrderSpecification
    attr_reader :field, :direction

    def initialize(field, direction)
      @field = field
      @direction = direction
      freeze
    end
  end

  class Field
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

    def eq(value)
      Condition.new(self, :eq, value)
    end

    def ne(value)
      Condition.new(self, :ne, value)
    end

    def gt(value)
      Condition.new(self, :gt, value)
    end

    def lt(value)
      Condition.new(self, :lt, value)
    end

    def gte(value)
      Condition.new(self, :gte, value)
    end

    def lte(value)
      Condition.new(self, :lte, value)
    end

    def in(values)
      Condition.new(self, :in, values)
    end

    def like(pattern)
      Condition.new(self, :like, pattern)
    end

    def between(min, max)
      Condition.new(self, :between, [min, max])
    end

    def is_null
      Condition.new(self, :is_null, nil)
    end

    def is_not_null
      Condition.new(self, :is_not_null, nil)
    end

    def asc
      OrderSpecification.new(self, :asc)
    end

    def desc
      OrderSpecification.new(self, :desc)
    end
  end
end
