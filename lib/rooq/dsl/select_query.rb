# frozen_string_literal: true

module Rooq
  module DSL
    class SelectQuery
      attr_reader :selected_fields, :from_table, :conditions, :order_specs, :limit_value, :offset_value, :joins

      def initialize(fields)
        @selected_fields = fields.flatten.freeze
        @from_table = nil
        @conditions = nil
        @order_specs = []
        @limit_value = nil
        @offset_value = nil
        @joins = []
        freeze_after_build
      end

      def from(table)
        dup_with(from_table: table)
      end

      def where(condition)
        dup_with(conditions: condition)
      end

      def order_by(*specs)
        dup_with(order_specs: specs.flatten)
      end

      def limit(value)
        dup_with(limit_value: value)
      end

      def offset(value)
        dup_with(offset_value: value)
      end

      def inner_join(table)
        JoinBuilder.new(self, :inner, table)
      end

      def left_join(table)
        JoinBuilder.new(self, :left, table)
      end

      def right_join(table)
        JoinBuilder.new(self, :right, table)
      end

      def add_join(join)
        dup_with(joins: @joins + [join])
      end

      def to_sql(dialect = Rooq::Dialect::PostgreSQL.new)
        dialect.render_select(self)
      end

      private

      def freeze_after_build
        # Don't freeze during construction
      end

      def dup_with(**changes)
        new_query = self.class.allocate
        new_query.instance_variable_set(:@selected_fields, changes.fetch(:selected_fields, @selected_fields))
        new_query.instance_variable_set(:@from_table, changes.fetch(:from_table, @from_table))
        new_query.instance_variable_set(:@conditions, changes.fetch(:conditions, @conditions))
        new_query.instance_variable_set(:@order_specs, changes.fetch(:order_specs, @order_specs))
        new_query.instance_variable_set(:@limit_value, changes.fetch(:limit_value, @limit_value))
        new_query.instance_variable_set(:@offset_value, changes.fetch(:offset_value, @offset_value))
        new_query.instance_variable_set(:@joins, changes.fetch(:joins, @joins))
        new_query
      end
    end

    class JoinBuilder
      def initialize(query, type, table)
        @query = query
        @type = type
        @table = table
      end

      def on(condition)
        join = Join.new(@type, @table, condition)
        @query.add_join(join)
      end
    end

    class Join
      attr_reader :type, :table, :condition

      def initialize(type, table, condition)
        @type = type
        @table = table
        @condition = condition
        freeze
      end
    end
  end
end
