# frozen_string_literal: true

module Rooq
  module DSL
    class InsertQuery
      attr_reader :table, :column_list, :insert_values, :returning_fields

      def initialize(table)
        @table = table
        @column_list = []
        @insert_values = []
        @returning_fields = []
      end

      def columns(*cols)
        dup_with(column_list: cols.flatten)
      end

      def values(*vals)
        dup_with(insert_values: @insert_values + [vals.flatten])
      end

      def returning(*fields)
        dup_with(returning_fields: fields.flatten)
      end

      def to_sql(dialect = Rooq::Dialect::PostgreSQL.new)
        dialect.render_insert(self)
      end

      private

      def dup_with(**changes)
        new_query = self.class.allocate
        new_query.instance_variable_set(:@table, changes.fetch(:table, @table))
        new_query.instance_variable_set(:@column_list, changes.fetch(:column_list, @column_list))
        new_query.instance_variable_set(:@insert_values, changes.fetch(:insert_values, @insert_values))
        new_query.instance_variable_set(:@returning_fields, changes.fetch(:returning_fields, @returning_fields))
        new_query
      end
    end
  end
end
