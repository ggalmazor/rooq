# frozen_string_literal: true

module Rooq
  module DSL
    class SelectQuery
      attr_reader :selected_fields, :from_table, :conditions, :order_specs,
                  :limit_value, :offset_value, :joins, :distinct_flag,
                  :group_by_fields, :having_condition, :ctes, :for_update_flag,
                  :table_alias

      def initialize(fields)
        @selected_fields = fields.flatten.freeze
        @from_table = nil
        @table_alias = nil
        @conditions = nil
        @order_specs = []
        @limit_value = nil
        @offset_value = nil
        @joins = []
        @distinct_flag = false
        @group_by_fields = []
        @having_condition = nil
        @ctes = []
        @for_update_flag = false
      end

      def distinct
        dup_with(distinct_flag: true)
      end

      def from(table, as: nil)
        dup_with(from_table: table, table_alias: as)
      end

      def where(condition)
        if @conditions
          dup_with(conditions: @conditions.and(condition))
        else
          dup_with(conditions: condition)
        end
      end

      def and_where(condition)
        where(condition)
      end

      def or_where(condition)
        if @conditions
          dup_with(conditions: @conditions.or(condition))
        else
          dup_with(conditions: condition)
        end
      end

      def group_by(*fields)
        dup_with(group_by_fields: @group_by_fields + fields.flatten)
      end

      def having(condition)
        if @having_condition
          dup_with(having_condition: @having_condition.and(condition))
        else
          dup_with(having_condition: condition)
        end
      end

      def order_by(*specs)
        dup_with(order_specs: @order_specs + specs.flatten)
      end

      def limit(value)
        dup_with(limit_value: value)
      end

      def offset(value)
        dup_with(offset_value: value)
      end

      def for_update
        dup_with(for_update_flag: true)
      end

      # JOIN methods
      def inner_join(table, as: nil)
        JoinBuilder.new(self, :inner, table, as)
      end

      def left_join(table, as: nil)
        JoinBuilder.new(self, :left, table, as)
      end

      def right_join(table, as: nil)
        JoinBuilder.new(self, :right, table, as)
      end

      def full_join(table, as: nil)
        JoinBuilder.new(self, :full, table, as)
      end

      def cross_join(table, as: nil)
        join = Join.new(:cross, table, nil, as)
        dup_with(joins: @joins + [join])
      end

      def add_join(join)
        dup_with(joins: @joins + [join])
      end

      # CTE support
      def with(name, query, recursive: false)
        cte = CTE.new(name, query, recursive: recursive)
        dup_with(ctes: @ctes + [cte])
      end

      # Set operations - return a new combined query
      def union(other, all: false)
        SetOperation.new(:union, self, other, all: all)
      end

      def intersect(other, all: false)
        SetOperation.new(:intersect, self, other, all: all)
      end

      def except(other, all: false)
        SetOperation.new(:except, self, other, all: all)
      end

      # Convert to subquery for use in FROM or conditions
      def as_subquery(alias_name)
        Subquery.new(self, alias_name)
      end

      def to_sql(dialect = Rooq::Dialect::PostgreSQL.new)
        dialect.render_select(self)
      end

      private

      def dup_with(**changes)
        new_query = self.class.allocate
        new_query.instance_variable_set(:@selected_fields, changes.fetch(:selected_fields, @selected_fields))
        new_query.instance_variable_set(:@from_table, changes.fetch(:from_table, @from_table))
        new_query.instance_variable_set(:@table_alias, changes.fetch(:table_alias, @table_alias))
        new_query.instance_variable_set(:@conditions, changes.fetch(:conditions, @conditions))
        new_query.instance_variable_set(:@order_specs, changes.fetch(:order_specs, @order_specs))
        new_query.instance_variable_set(:@limit_value, changes.fetch(:limit_value, @limit_value))
        new_query.instance_variable_set(:@offset_value, changes.fetch(:offset_value, @offset_value))
        new_query.instance_variable_set(:@joins, changes.fetch(:joins, @joins))
        new_query.instance_variable_set(:@distinct_flag, changes.fetch(:distinct_flag, @distinct_flag))
        new_query.instance_variable_set(:@group_by_fields, changes.fetch(:group_by_fields, @group_by_fields))
        new_query.instance_variable_set(:@having_condition, changes.fetch(:having_condition, @having_condition))
        new_query.instance_variable_set(:@ctes, changes.fetch(:ctes, @ctes))
        new_query.instance_variable_set(:@for_update_flag, changes.fetch(:for_update_flag, @for_update_flag))
        new_query
      end
    end

    class JoinBuilder
      def initialize(query, type, table, table_alias)
        @query = query
        @type = type
        @table = table
        @table_alias = table_alias
      end

      def on(condition)
        join = Join.new(@type, @table, condition, @table_alias)
        @query.add_join(join)
      end

      def using(*columns)
        join = Join.new(@type, @table, nil, @table_alias, using: columns.flatten)
        @query.add_join(join)
      end
    end

    class Join
      attr_reader :type, :table, :condition, :table_alias, :using_columns

      def initialize(type, table, condition, table_alias = nil, using: nil)
        @type = type
        @table = table
        @condition = condition
        @table_alias = table_alias
        @using_columns = using&.freeze
        freeze
      end
    end

    class CTE
      attr_reader :name, :query, :recursive

      def initialize(name, query, recursive: false)
        @name = name
        @query = query
        @recursive = recursive
        freeze
      end
    end

    class Subquery
      attr_reader :query, :alias_name

      def initialize(query, alias_name)
        @query = query
        @alias_name = alias_name
        freeze
      end

      # Allow subquery to be used in conditions
      def in(values)
        Rooq::Condition.new(self, :in, values)
      end
    end

    class SetOperation
      attr_reader :operator, :left, :right, :all

      def initialize(operator, left, right, all: false)
        @operator = operator
        @left = left
        @right = right
        @all = all
        freeze
      end

      def to_sql(dialect = Rooq::Dialect::PostgreSQL.new)
        dialect.render_set_operation(self)
      end

      # Allow chaining
      def union(other, all: false)
        SetOperation.new(:union, self, other, all: all)
      end

      def intersect(other, all: false)
        SetOperation.new(:intersect, self, other, all: all)
      end

      def except(other, all: false)
        SetOperation.new(:except, self, other, all: all)
      end

      def order_by(*specs)
        OrderedSetOperation.new(self, specs.flatten)
      end
    end

    class OrderedSetOperation
      attr_reader :set_operation, :order_specs, :limit_value, :offset_value

      def initialize(set_operation, order_specs, limit_value: nil, offset_value: nil)
        @set_operation = set_operation
        @order_specs = order_specs.freeze
        @limit_value = limit_value
        @offset_value = offset_value
        freeze
      end

      def limit(value)
        OrderedSetOperation.new(@set_operation, @order_specs, limit_value: value, offset_value: @offset_value)
      end

      def offset(value)
        OrderedSetOperation.new(@set_operation, @order_specs, limit_value: @limit_value, offset_value: value)
      end

      def to_sql(dialect = Rooq::Dialect::PostgreSQL.new)
        dialect.render_ordered_set_operation(self)
      end
    end

    # Grouping sets for advanced GROUP BY
    class GroupingSets
      attr_reader :sets

      def initialize(*sets)
        @sets = sets.freeze
        freeze
      end
    end

    class Cube
      attr_reader :fields

      def initialize(*fields)
        @fields = fields.flatten.freeze
        freeze
      end
    end

    class Rollup
      attr_reader :fields

      def initialize(*fields)
        @fields = fields.flatten.freeze
        freeze
      end
    end
  end
end
