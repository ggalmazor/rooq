# frozen_string_literal: true

module Rooq
  class Condition
    attr_reader :expression, :operator, :value

    def initialize(expression, operator, value)
      @expression = expression
      @operator = operator
      @value = value
      freeze
    end

    # Backwards compatibility
    def field
      @expression
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

  # EXISTS condition
  class ExistsCondition
    attr_reader :subquery, :negated

    def initialize(subquery, negated: false)
      @subquery = subquery
      @negated = negated
      freeze
    end
  end

  # Helper methods for conditions
  def self.exists(subquery)
    ExistsCondition.new(subquery)
  end

  def self.not_exists(subquery)
    ExistsCondition.new(subquery, negated: true)
  end
end
