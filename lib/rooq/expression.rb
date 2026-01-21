# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

module Rooq
  # Base class for all SQL expressions
  class Expression
    extend T::Sig

    sig { params(alias_name: Symbol).returns(AliasedExpression) }
    def as(alias_name)
      AliasedExpression.new(self, alias_name)
    end

    sig { params(_dialect: T.untyped).returns(T.untyped) }
    def to_sql(_dialect)
      raise NotImplementedError, "Subclasses must implement #to_sql"
    end

    # Comparison operators return Conditions
    sig { params(other: T.untyped).returns(Condition) }
    def eq(other)
      Condition.new(self, :eq, other)
    end

    sig { params(other: T.untyped).returns(Condition) }
    def ne(other)
      Condition.new(self, :ne, other)
    end

    sig { params(other: T.untyped).returns(Condition) }
    def gt(other)
      Condition.new(self, :gt, other)
    end

    sig { params(other: T.untyped).returns(Condition) }
    def lt(other)
      Condition.new(self, :lt, other)
    end

    sig { params(other: T.untyped).returns(Condition) }
    def gte(other)
      Condition.new(self, :gte, other)
    end

    sig { params(other: T.untyped).returns(Condition) }
    def lte(other)
      Condition.new(self, :lte, other)
    end

    sig { params(values: T.any(T::Array[T.untyped], DSL::SelectQuery)).returns(Condition) }
    def in(values)
      Condition.new(self, :in, values)
    end

    sig { params(pattern: String).returns(Condition) }
    def like(pattern)
      Condition.new(self, :like, pattern)
    end

    sig { params(min: T.untyped, max: T.untyped).returns(Condition) }
    def between(min, max)
      Condition.new(self, :between, [min, max])
    end

    sig { returns(Condition) }
    def is_null
      Condition.new(self, :is_null, nil)
    end

    sig { returns(Condition) }
    def is_not_null
      Condition.new(self, :is_not_null, nil)
    end

    # Ordering
    sig { returns(OrderSpecification) }
    def asc
      OrderSpecification.new(self, :asc)
    end

    sig { returns(OrderSpecification) }
    def desc
      OrderSpecification.new(self, :desc)
    end

    # Arithmetic operators
    sig { params(other: T.any(Expression, Numeric)).returns(ArithmeticExpression) }
    def +(other)
      ArithmeticExpression.new(self, :+, other)
    end

    sig { params(other: T.any(Expression, Numeric)).returns(ArithmeticExpression) }
    def -(other)
      ArithmeticExpression.new(self, :-, other)
    end

    sig { params(other: T.any(Expression, Numeric)).returns(ArithmeticExpression) }
    def *(other)
      ArithmeticExpression.new(self, :*, other)
    end

    sig { params(other: T.any(Expression, Numeric)).returns(ArithmeticExpression) }
    def /(other)
      ArithmeticExpression.new(self, :/, other)
    end

    sig { params(other: T.any(Expression, Numeric)).returns(ArithmeticExpression) }
    def %(other)
      ArithmeticExpression.new(self, :%, other)
    end
  end

  class AliasedExpression < Expression
    extend T::Sig

    sig { returns(Expression) }
    attr_reader :expression

    sig { returns(Symbol) }
    attr_reader :alias_name

    sig { params(expression: Expression, alias_name: Symbol).void }
    def initialize(expression, alias_name)
      @expression = expression
      @alias_name = alias_name
      freeze
    end
  end

  class ArithmeticExpression < Expression
    extend T::Sig

    sig { returns(T.any(Expression, Numeric)) }
    attr_reader :left

    sig { returns(Symbol) }
    attr_reader :operator

    sig { returns(T.any(Expression, Numeric)) }
    attr_reader :right

    sig { params(left: T.any(Expression, Numeric), operator: Symbol, right: T.any(Expression, Numeric)).void }
    def initialize(left, operator, right)
      @left = left
      @operator = operator
      @right = right
      freeze
    end
  end

  class Literal < Expression
    extend T::Sig

    sig { returns(T.untyped) }
    attr_reader :value

    sig { params(value: T.untyped).void }
    def initialize(value)
      @value = value
      freeze
    end
  end

  # Function call expression
  class FunctionCall < Expression
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :name

    sig { returns(T::Array[T.untyped]) }
    attr_reader :arguments

    sig { returns(T::Boolean) }
    attr_reader :distinct

    sig { params(name: Symbol, arguments: T.untyped, distinct: T::Boolean).void }
    def initialize(name, *arguments, distinct: false)
      @name = name
      @arguments = T.let(arguments.flatten.freeze, T::Array[T.untyped])
      @distinct = distinct
      freeze
    end
  end

  # Aggregate functions
  module Aggregates
    extend T::Sig

    class << self
      extend T::Sig

      sig { params(expression: T.nilable(Expression), distinct: T::Boolean).returns(FunctionCall) }
      def count(expression = nil, distinct: false)
        expression ||= Literal.new(:*)
        FunctionCall.new(:count, expression, distinct: distinct)
      end

      sig { params(expression: Expression, distinct: T::Boolean).returns(FunctionCall) }
      def sum(expression, distinct: false)
        FunctionCall.new(:sum, expression, distinct: distinct)
      end

      sig { params(expression: Expression, distinct: T::Boolean).returns(FunctionCall) }
      def avg(expression, distinct: false)
        FunctionCall.new(:avg, expression, distinct: distinct)
      end

      sig { params(expression: Expression).returns(FunctionCall) }
      def min(expression)
        FunctionCall.new(:min, expression)
      end

      sig { params(expression: Expression).returns(FunctionCall) }
      def max(expression)
        FunctionCall.new(:max, expression)
      end

      sig { params(expression: Expression, distinct: T::Boolean).returns(FunctionCall) }
      def array_agg(expression, distinct: false)
        FunctionCall.new(:array_agg, expression, distinct: distinct)
      end

      sig { params(expression: Expression, delimiter: String, distinct: T::Boolean).returns(FunctionCall) }
      def string_agg(expression, delimiter, distinct: false)
        FunctionCall.new(:string_agg, expression, delimiter, distinct: distinct)
      end
    end
  end

  # Window function expression
  class WindowFunction < Expression
    extend T::Sig

    FrameBound = T.type_alias { T.any(Symbol, T::Array[T.any(Symbol, Integer)]) }

    sig { returns(FunctionCall) }
    attr_reader :function

    sig { returns(T.nilable(WindowFrame)) }
    attr_reader :frame

    sig do
      params(
        function: FunctionCall,
        partition_fields: T::Array[Expression],
        order_specs: T::Array[OrderSpecification],
        frame: T.nilable(WindowFrame)
      ).void
    end
    def initialize(function, partition_fields: [], order_specs: [], frame: nil)
      @function = function
      @partition_fields = T.let(Array(partition_fields).freeze, T::Array[Expression])
      @order_specs = T.let(Array(order_specs).freeze, T::Array[OrderSpecification])
      @frame = frame
    end

    sig { params(fields: Expression).returns(T.any(T::Array[Expression], WindowFunction)) }
    def partition_by(*fields)
      return @partition_fields if fields.empty?
      WindowFunction.new(@function, partition_fields: @partition_fields + fields.flatten, order_specs: @order_specs, frame: @frame)
    end

    sig { params(specs: OrderSpecification).returns(T.any(T::Array[OrderSpecification], WindowFunction)) }
    def order_by(*specs)
      return @order_specs if specs.empty?
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs + specs.flatten, frame: @frame)
    end

    sig { params(start_bound: FrameBound, end_bound: T.nilable(FrameBound)).returns(WindowFunction) }
    def rows(start_bound, end_bound = nil)
      new_frame = WindowFrame.new(WindowFrame::ROWS, start_bound, end_bound)
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs, frame: new_frame)
    end

    sig { params(start_bound: FrameBound, end_bound: FrameBound).returns(WindowFunction) }
    def rows_between(start_bound, end_bound)
      new_frame = WindowFrame.new(WindowFrame::ROWS, start_bound, end_bound)
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs, frame: new_frame)
    end

    sig { params(start_bound: FrameBound, end_bound: FrameBound).returns(WindowFunction) }
    def range_between(start_bound, end_bound)
      new_frame = WindowFrame.new(WindowFrame::RANGE, start_bound, end_bound)
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs, frame: new_frame)
    end

    sig do
      params(
        partition_by: T::Array[Expression],
        order_by: T::Array[OrderSpecification],
        frame: T.nilable(WindowFrame)
      ).returns(WindowFunction)
    end
    def over(partition_by: [], order_by: [], frame: nil)
      WindowFunction.new(@function, partition_fields: partition_by, order_specs: order_by, frame: frame)
    end
  end

  # Window frame specification
  class WindowFrame
    extend T::Sig

    FrameBound = T.type_alias { T.any(Symbol, T::Array[T.any(Symbol, Integer)]) }

    sig { returns(Symbol) }
    attr_reader :type

    sig { returns(FrameBound) }
    attr_reader :start_bound

    sig { returns(T.nilable(FrameBound)) }
    attr_reader :end_bound

    ROWS = T.let(:rows, Symbol)
    RANGE = T.let(:range, Symbol)
    GROUPS = T.let(:groups, Symbol)

    UNBOUNDED_PRECEDING = T.let(:unbounded_preceding, Symbol)
    CURRENT_ROW = T.let(:current_row, Symbol)
    UNBOUNDED_FOLLOWING = T.let(:unbounded_following, Symbol)

    sig { params(type: Symbol, start_bound: FrameBound, end_bound: T.nilable(FrameBound)).void }
    def initialize(type, start_bound, end_bound = nil)
      @type = type
      @start_bound = start_bound
      @end_bound = end_bound
      freeze
    end

    class << self
      extend T::Sig

      sig { params(start_bound: FrameBound, end_bound: T.nilable(FrameBound)).returns(WindowFrame) }
      def rows(start_bound, end_bound = nil)
        WindowFrame.new(ROWS, start_bound, end_bound)
      end

      sig { params(start_bound: FrameBound, end_bound: T.nilable(FrameBound)).returns(WindowFrame) }
      def range(start_bound, end_bound = nil)
        WindowFrame.new(RANGE, start_bound, end_bound)
      end

      sig { params(n: Integer).returns(T::Array[T.any(Symbol, Integer)]) }
      def preceding(n)
        [:preceding, n]
      end

      sig { params(n: Integer).returns(T::Array[T.any(Symbol, Integer)]) }
      def following(n)
        [:following, n]
      end
    end
  end

  # Window functions module
  module WindowFunctions
    extend T::Sig

    class << self
      extend T::Sig

      sig { returns(WindowFunction) }
      def row_number
        WindowFunction.new(FunctionCall.new(:row_number))
      end

      sig { returns(WindowFunction) }
      def rank
        WindowFunction.new(FunctionCall.new(:rank))
      end

      sig { returns(WindowFunction) }
      def dense_rank
        WindowFunction.new(FunctionCall.new(:dense_rank))
      end

      sig { params(n: Integer).returns(WindowFunction) }
      def ntile(n)
        WindowFunction.new(FunctionCall.new(:ntile, Literal.new(n)))
      end

      sig { params(expression: Expression, offset: Integer, default: T.nilable(T.untyped)).returns(WindowFunction) }
      def lag(expression, offset = 1, default = nil)
        args = [expression, Literal.new(offset)]
        args << default if default
        WindowFunction.new(FunctionCall.new(:lag, *args))
      end

      sig { params(expression: Expression, offset: Integer, default: T.nilable(T.untyped)).returns(WindowFunction) }
      def lead(expression, offset = 1, default = nil)
        args = [expression, Literal.new(offset)]
        args << default if default
        WindowFunction.new(FunctionCall.new(:lead, *args))
      end

      sig { params(expression: Expression).returns(WindowFunction) }
      def first_value(expression)
        WindowFunction.new(FunctionCall.new(:first_value, expression))
      end

      sig { params(expression: Expression).returns(WindowFunction) }
      def last_value(expression)
        WindowFunction.new(FunctionCall.new(:last_value, expression))
      end

      sig { params(expression: Expression, n: Integer).returns(WindowFunction) }
      def nth_value(expression, n)
        WindowFunction.new(FunctionCall.new(:nth_value, expression, Literal.new(n)))
      end
    end
  end

  # CASE WHEN expression
  class CaseExpression < Expression
    extend T::Sig

    CasePair = T.type_alias { [Condition, Expression] }

    sig { returns(T::Array[CasePair]) }
    attr_reader :cases

    sig { returns(T.nilable(Expression)) }
    attr_reader :else_result

    sig { void }
    def initialize
      @cases = T.let([], T::Array[CasePair])
      @else_result = T.let(nil, T.nilable(Expression))
    end

    sig { params(condition: Condition, result: Expression).returns(CaseExpression) }
    def when(condition, result)
      new_case = CaseExpression.new
      new_case.instance_variable_set(:@cases, @cases + [[condition, result]])
      new_case.instance_variable_set(:@else_result, @else_result)
      new_case
    end

    sig { params(result: Expression).returns(CaseExpression) }
    def else(result)
      new_case = CaseExpression.new
      new_case.instance_variable_set(:@cases, @cases.dup)
      new_case.instance_variable_set(:@else_result, result)
      new_case.freeze
      new_case
    end
  end

  extend T::Sig

  # Helper to create CASE expressions
  sig { returns(CaseExpression) }
  def self.case_when
    CaseExpression.new
  end

  # COALESCE function
  sig { params(expressions: Expression).returns(FunctionCall) }
  def self.coalesce(*expressions)
    FunctionCall.new(:coalesce, *expressions)
  end

  # NULLIF function
  sig { params(expr1: Expression, expr2: Expression).returns(FunctionCall) }
  def self.nullif(expr1, expr2)
    FunctionCall.new(:nullif, expr1, expr2)
  end

  # CAST expression
  class CastExpression < Expression
    extend T::Sig

    sig { returns(Expression) }
    attr_reader :expression

    sig { returns(T.any(String, Symbol)) }
    attr_reader :target_type

    sig { params(expression: Expression, target_type: T.any(String, Symbol)).void }
    def initialize(expression, target_type)
      @expression = expression
      @target_type = target_type
      freeze
    end
  end

  sig { params(expression: Expression, as: T.any(String, Symbol)).returns(CastExpression) }
  def self.cast(expression, as:)
    CastExpression.new(expression, as)
  end
end
