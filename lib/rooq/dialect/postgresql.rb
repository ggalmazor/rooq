# frozen_string_literal: true

module Rooq
  module Dialect
    class PostgreSQL < Base
      def render_select(query)
        params = []
        sql_parts = []

        # SELECT clause
        fields = render_fields(query.selected_fields)
        sql_parts << "SELECT #{fields}"

        # FROM clause
        sql_parts << "FROM #{render_table_name(query.from_table)}" if query.from_table

        # JOIN clauses
        query.joins.each do |join|
          sql_parts << render_join(join, params)
        end

        # WHERE clause
        if query.conditions
          condition_sql = render_condition(query.conditions, params)
          sql_parts << "WHERE #{condition_sql}"
        end

        # ORDER BY clause
        unless query.order_specs.empty?
          order_parts = query.order_specs.map { |spec| render_order_spec(spec) }
          sql_parts << "ORDER BY #{order_parts.join(', ')}"
        end

        # LIMIT clause
        sql_parts << "LIMIT #{query.limit_value}" if query.limit_value

        # OFFSET clause
        sql_parts << "OFFSET #{query.offset_value}" if query.offset_value

        RenderedQuery.new(sql_parts.join(" "), params)
      end

      def render_insert(query)
        params = []
        sql_parts = []

        sql_parts << "INSERT INTO #{render_table_name(query.table)}"

        # Columns
        columns = query.column_list.map { |col| render_field_name(col) }
        sql_parts << "(#{columns.join(', ')})"

        # Values
        value_groups = query.insert_values.map do |values|
          placeholders = values.map do |value|
            params << value
            "$#{params.length}"
          end
          "(#{placeholders.join(', ')})"
        end
        sql_parts << "VALUES #{value_groups.join(', ')}"

        # RETURNING clause
        unless query.returning_fields.empty?
          fields = render_fields(query.returning_fields)
          sql_parts << "RETURNING #{fields}"
        end

        RenderedQuery.new(sql_parts.join(" "), params)
      end

      def render_update(query)
        params = []
        sql_parts = []

        sql_parts << "UPDATE #{render_table_name(query.table)}"

        # SET clause
        set_parts = query.set_values.map do |field, value|
          params << value
          "#{render_field_name(field)} = $#{params.length}"
        end
        sql_parts << "SET #{set_parts.join(', ')}"

        # WHERE clause
        if query.conditions
          condition_sql = render_condition(query.conditions, params)
          sql_parts << "WHERE #{condition_sql}"
        end

        # RETURNING clause
        unless query.returning_fields.empty?
          fields = render_fields(query.returning_fields)
          sql_parts << "RETURNING #{fields}"
        end

        RenderedQuery.new(sql_parts.join(" "), params)
      end

      def render_delete(query)
        params = []
        sql_parts = []

        sql_parts << "DELETE FROM #{render_table_name(query.table)}"

        # WHERE clause
        if query.conditions
          condition_sql = render_condition(query.conditions, params)
          sql_parts << "WHERE #{condition_sql}"
        end

        # RETURNING clause
        unless query.returning_fields.empty?
          fields = render_fields(query.returning_fields)
          sql_parts << "RETURNING #{fields}"
        end

        RenderedQuery.new(sql_parts.join(" "), params)
      end

      def render_condition(condition, params)
        case condition
        when Condition
          render_simple_condition(condition, params)
        when CombinedCondition
          render_combined_condition(condition, params)
        else
          raise ArgumentError, "Unknown condition type: #{condition.class}"
        end
      end

      private

      def render_fields(fields)
        fields.map { |f| render_field(f) }.join(", ")
      end

      def render_field(field)
        case field
        when Field
          field.qualified_name
        when Symbol
          field.to_s
        else
          field.to_s
        end
      end

      def render_field_name(field)
        case field
        when Field
          field.name.to_s
        when Symbol
          field.to_s
        else
          field.to_s
        end
      end

      def render_table_name(table)
        case table
        when Table
          table.name.to_s
        when Symbol
          table.to_s
        else
          table.to_s
        end
      end

      def render_join(join, params)
        join_type = case join.type
                    when :inner then "INNER JOIN"
                    when :left then "LEFT JOIN"
                    when :right then "RIGHT JOIN"
                    else raise ArgumentError, "Unknown join type: #{join.type}"
                    end

        condition_sql = render_condition(join.condition, params)
        "#{join_type} #{render_table_name(join.table)} ON #{condition_sql}"
      end

      def render_order_spec(spec)
        direction = spec.direction == :desc ? "DESC" : "ASC"
        "#{spec.field.qualified_name} #{direction}"
      end

      def render_simple_condition(condition, params)
        field_name = condition.field.qualified_name

        case condition.operator
        when :eq
          params << condition.value
          "#{field_name} = $#{params.length}"
        when :ne
          params << condition.value
          "#{field_name} <> $#{params.length}"
        when :gt
          params << condition.value
          "#{field_name} > $#{params.length}"
        when :lt
          params << condition.value
          "#{field_name} < $#{params.length}"
        when :gte
          params << condition.value
          "#{field_name} >= $#{params.length}"
        when :lte
          params << condition.value
          "#{field_name} <= $#{params.length}"
        when :in
          placeholders = condition.value.map do |v|
            params << v
            "$#{params.length}"
          end
          "#{field_name} IN (#{placeholders.join(', ')})"
        when :like
          params << condition.value
          "#{field_name} LIKE $#{params.length}"
        when :between
          params << condition.value[0]
          min_placeholder = "$#{params.length}"
          params << condition.value[1]
          max_placeholder = "$#{params.length}"
          "#{field_name} BETWEEN #{min_placeholder} AND #{max_placeholder}"
        when :is_null
          "#{field_name} IS NULL"
        when :is_not_null
          "#{field_name} IS NOT NULL"
        else
          raise ArgumentError, "Unknown operator: #{condition.operator}"
        end
      end

      def render_combined_condition(condition, params)
        parts = condition.conditions.map { |c| render_condition(c, params) }
        connector = condition.operator == :and ? " AND " : " OR "
        "(#{parts.join(connector)})"
      end
    end

    class RenderedQuery
      attr_reader :sql, :params

      def initialize(sql, params)
        @sql = sql.freeze
        @params = params.freeze
        freeze
      end
    end
  end
end
