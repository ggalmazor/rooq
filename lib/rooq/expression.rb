# frozen_string_literal: true

module Rooq
  # Base class for all SQL expressions
  class Expression
    def as(alias_name)
      AliasedExpression.new(self, alias_name)
    end

    def to_sql(_dialect)
      raise NotImplementedError, "Subclasses must implement #to_sql"
    end

    # Comparison operators return Conditions
    def eq(other)
      Condition.new(self, :eq, other)
    end

    def ne(other)
      Condition.new(self, :ne, other)
    end

    def gt(other)
      Condition.new(self, :gt, other)
    end

    def lt(other)
      Condition.new(self, :lt, other)
    end

    def gte(other)
      Condition.new(self, :gte, other)
    end

    def lte(other)
      Condition.new(self, :lte, other)
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

    # Ordering
    def asc
      OrderSpecification.new(self, :asc)
    end

    def desc
      OrderSpecification.new(self, :desc)
    end

    # Arithmetic operators
    def +(other)
      ArithmeticExpression.new(self, :+, other)
    end

    def -(other)
      ArithmeticExpression.new(self, :-, other)
    end

    def *(other)
      ArithmeticExpression.new(self, :*, other)
    end

    def /(other)
      ArithmeticExpression.new(self, :/, other)
    end

    def %(other)
      ArithmeticExpression.new(self, :%, other)
    end
  end

  class AliasedExpression < Expression
    attr_reader :expression, :alias_name

    def initialize(expression, alias_name)
      @expression = expression
      @alias_name = alias_name
      freeze
    end
  end

  class ArithmeticExpression < Expression
    attr_reader :left, :operator, :right

    def initialize(left, operator, right)
      @left = left
      @operator = operator
      @right = right
      freeze
    end
  end

  class Literal < Expression
    attr_reader :value

    def initialize(value)
      @value = value
      freeze
    end
  end

  # Function call expression
  class FunctionCall < Expression
    attr_reader :name, :arguments, :distinct

    def initialize(name, *arguments, distinct: false)
      @name = name
      @arguments = arguments.flatten.freeze
      @distinct = distinct
      freeze
    end
  end

  # Aggregate functions
  module Aggregates
    class << self
      def count(expression = nil, distinct: false)
        expression ||= Literal.new(:*)
        FunctionCall.new(:count, expression, distinct: distinct)
      end

      def sum(expression, distinct: false)
        FunctionCall.new(:sum, expression, distinct: distinct)
      end

      def avg(expression, distinct: false)
        FunctionCall.new(:avg, expression, distinct: distinct)
      end

      def min(expression)
        FunctionCall.new(:min, expression)
      end

      def max(expression)
        FunctionCall.new(:max, expression)
      end

      def array_agg(expression, distinct: false)
        FunctionCall.new(:array_agg, expression, distinct: distinct)
      end

      def string_agg(expression, delimiter, distinct: false)
        FunctionCall.new(:string_agg, expression, delimiter, distinct: distinct)
      end
    end
  end

  # Window function expression
  class WindowFunction < Expression
    attr_reader :function, :frame

    def initialize(function, partition_fields: [], order_specs: [], frame: nil)
      @function = function
      @partition_fields = Array(partition_fields).freeze
      @order_specs = Array(order_specs).freeze
      @frame = frame
    end

    def partition_by(*fields)
      return @partition_fields if fields.empty?
      WindowFunction.new(@function, partition_fields: @partition_fields + fields.flatten, order_specs: @order_specs, frame: @frame)
    end

    def order_by(*specs)
      return @order_specs if specs.empty?
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs + specs.flatten, frame: @frame)
    end

    def rows(start_bound, end_bound = nil)
      new_frame = WindowFrame.new(WindowFrame::ROWS, start_bound, end_bound)
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs, frame: new_frame)
    end

    def rows_between(start_bound, end_bound)
      new_frame = WindowFrame.new(WindowFrame::ROWS, start_bound, end_bound)
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs, frame: new_frame)
    end

    def range_between(start_bound, end_bound)
      new_frame = WindowFrame.new(WindowFrame::RANGE, start_bound, end_bound)
      WindowFunction.new(@function, partition_fields: @partition_fields, order_specs: @order_specs, frame: new_frame)
    end

    def over(partition_by: [], order_by: [], frame: nil)
      WindowFunction.new(@function, partition_fields: partition_by, order_specs: order_by, frame: frame)
    end
  end

  # Window frame specification
  class WindowFrame
    attr_reader :type, :start_bound, :end_bound

    ROWS = :rows
    RANGE = :range
    GROUPS = :groups

    UNBOUNDED_PRECEDING = :unbounded_preceding
    CURRENT_ROW = :current_row
    UNBOUNDED_FOLLOWING = :unbounded_following

    def initialize(type, start_bound, end_bound = nil)
      @type = type
      @start_bound = start_bound
      @end_bound = end_bound
      freeze
    end

    class << self
      def rows(start_bound, end_bound = nil)
        WindowFrame.new(ROWS, start_bound, end_bound)
      end

      def range(start_bound, end_bound = nil)
        WindowFrame.new(RANGE, start_bound, end_bound)
      end

      def preceding(n)
        [:preceding, n]
      end

      def following(n)
        [:following, n]
      end
    end
  end

  # Window functions module
  module WindowFunctions
    class << self
      def row_number
        WindowFunction.new(FunctionCall.new(:row_number))
      end

      def rank
        WindowFunction.new(FunctionCall.new(:rank))
      end

      def dense_rank
        WindowFunction.new(FunctionCall.new(:dense_rank))
      end

      def ntile(n)
        WindowFunction.new(FunctionCall.new(:ntile, Literal.new(n)))
      end

      def lag(expression, offset = 1, default = nil)
        args = [expression, Literal.new(offset)]
        args << default if default
        WindowFunction.new(FunctionCall.new(:lag, *args))
      end

      def lead(expression, offset = 1, default = nil)
        args = [expression, Literal.new(offset)]
        args << default if default
        WindowFunction.new(FunctionCall.new(:lead, *args))
      end

      def first_value(expression)
        WindowFunction.new(FunctionCall.new(:first_value, expression))
      end

      def last_value(expression)
        WindowFunction.new(FunctionCall.new(:last_value, expression))
      end

      def nth_value(expression, n)
        WindowFunction.new(FunctionCall.new(:nth_value, expression, Literal.new(n)))
      end
    end
  end

  # CASE WHEN expression
  class CaseExpression < Expression
    attr_reader :cases, :else_result

    def initialize
      @cases = []
      @else_result = nil
    end

    def when(condition, result)
      new_case = CaseExpression.new
      new_case.instance_variable_set(:@cases, @cases + [[condition, result]])
      new_case.instance_variable_set(:@else_result, @else_result)
      new_case
    end

    def else(result)
      new_case = CaseExpression.new
      new_case.instance_variable_set(:@cases, @cases.dup)
      new_case.instance_variable_set(:@else_result, result)
      new_case.freeze
      new_case
    end
  end

  # Helper to create CASE expressions
  def self.case_when
    CaseExpression.new
  end

  # COALESCE function
  def self.coalesce(*expressions)
    FunctionCall.new(:coalesce, *expressions)
  end

  # NULLIF function
  def self.nullif(expr1, expr2)
    FunctionCall.new(:nullif, expr1, expr2)
  end

  # CAST expression
  class CastExpression < Expression
    attr_reader :expression, :target_type

    def initialize(expression, target_type)
      @expression = expression
      @target_type = target_type
      freeze
    end
  end

  def self.cast(expression, as:)
    CastExpression.new(expression, as)
  end
end
