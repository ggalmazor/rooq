# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Rooq
  class OrderSpecification
    extend T::Sig

    NullsPosition = T.type_alias { T.nilable(Symbol) }

    sig { returns(Expression) }
    attr_reader :expression

    sig { returns(Symbol) }
    attr_reader :direction

    sig { returns(NullsPosition) }
    attr_reader :nulls

    sig { params(expression: Expression, direction: Symbol, nulls: NullsPosition).void }
    def initialize(expression, direction, nulls: nil)
      @expression = expression
      @direction = direction
      @nulls = nulls
      freeze
    end

    sig { returns(OrderSpecification) }
    def nulls_first
      OrderSpecification.new(@expression, @direction, nulls: :first)
    end

    sig { returns(OrderSpecification) }
    def nulls_last
      OrderSpecification.new(@expression, @direction, nulls: :last)
    end

    # For backwards compatibility
    sig { returns(Expression) }
    def field
      @expression
    end
  end

  class Field < Expression
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :name

    sig { returns(Symbol) }
    attr_reader :table_name

    sig { returns(Symbol) }
    attr_reader :type

    sig { params(name: Symbol, table_name: Symbol, type: Symbol).void }
    def initialize(name, table_name, type)
      @name = name
      @table_name = table_name
      @type = type
      freeze
    end

    sig { returns(String) }
    def qualified_name
      "#{table_name}.#{name}"
    end
  end
end
