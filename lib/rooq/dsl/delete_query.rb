# frozen_string_literal: true

module Rooq
  module DSL
    class DeleteQuery
      attr_reader :table, :conditions, :returning_fields

      def initialize(table)
        @table = table
        @conditions = nil
        @returning_fields = []
      end

      def where(condition)
        dup_with(conditions: condition)
      end

      def returning(*fields)
        dup_with(returning_fields: fields.flatten)
      end

      def to_sql(dialect = Rooq::Dialect::PostgreSQL.new)
        dialect.render_delete(self)
      end

      private

      def dup_with(**changes)
        new_query = self.class.allocate
        new_query.instance_variable_set(:@table, changes.fetch(:table, @table))
        new_query.instance_variable_set(:@conditions, changes.fetch(:conditions, @conditions))
        new_query.instance_variable_set(:@returning_fields, changes.fetch(:returning_fields, @returning_fields))
        new_query
      end
    end
  end
end
