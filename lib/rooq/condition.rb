# frozen_string_literal: true

module Rooq
  class Condition
    attr_reader :field, :operator, :value

    def initialize(field, operator, value)
      @field = field
      @operator = operator
      @value = value
      freeze
    end

    def and(other)
      CombinedCondition.new(:and, [self, other])
    end

    def or(other)
      CombinedCondition.new(:or, [self, other])
    end
  end

  class CombinedCondition
    attr_reader :operator, :conditions

    def initialize(operator, conditions)
      @operator = operator
      @conditions = conditions.freeze
      freeze
    end

    def and(other)
      CombinedCondition.new(:and, [*@conditions, other])
    end

    def or(other)
      CombinedCondition.new(:or, [*@conditions, other])
    end
  end
end
