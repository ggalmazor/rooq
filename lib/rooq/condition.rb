# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Rooq
  # Type alias for any condition type
  AnyCondition = T.type_alias { T.any(Condition, CombinedCondition, ExistsCondition) }

  class Condition
    extend T::Sig

    sig { returns(Expression) }
    attr_reader :expression

    sig { returns(Symbol) }
    attr_reader :operator

    sig { returns(T.untyped) }
    attr_reader :value

    sig { params(expression: Expression, operator: Symbol, value: T.untyped).void }
    def initialize(expression, operator, value)
      @expression = expression
      @operator = operator
      @value = value
      freeze
    end

    # Backwards compatibility
    sig { returns(Expression) }
    def field
      @expression
    end

    sig { params(other: AnyCondition).returns(CombinedCondition) }
    def and(other)
      CombinedCondition.new(:and, [self, other])
    end

    sig { params(other: AnyCondition).returns(CombinedCondition) }
    def or(other)
      CombinedCondition.new(:or, [self, other])
    end
  end

  class CombinedCondition
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :operator

    sig { returns(T::Array[AnyCondition]) }
    attr_reader :conditions

    sig { params(operator: Symbol, conditions: T::Array[AnyCondition]).void }
    def initialize(operator, conditions)
      @operator = operator
      @conditions = T.let(conditions.freeze, T::Array[AnyCondition])
      freeze
    end

    sig { params(other: AnyCondition).returns(CombinedCondition) }
    def and(other)
      CombinedCondition.new(:and, [*@conditions, other])
    end

    sig { params(other: AnyCondition).returns(CombinedCondition) }
    def or(other)
      CombinedCondition.new(:or, [*@conditions, other])
    end
  end

  # EXISTS condition
  class ExistsCondition
    extend T::Sig

    sig { returns(DSL::SelectQuery) }
    attr_reader :subquery

    sig { returns(T::Boolean) }
    attr_reader :negated

    sig { params(subquery: DSL::SelectQuery, negated: T::Boolean).void }
    def initialize(subquery, negated: false)
      @subquery = subquery
      @negated = negated
      freeze
    end
  end

  extend T::Sig

  # Helper methods for conditions
  sig { params(subquery: DSL::SelectQuery).returns(ExistsCondition) }
  def self.exists(subquery)
    ExistsCondition.new(subquery)
  end

  sig { params(subquery: DSL::SelectQuery).returns(ExistsCondition) }
  def self.not_exists(subquery)
    ExistsCondition.new(subquery, negated: true)
  end
end
