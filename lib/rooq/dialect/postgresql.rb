# frozen_string_literal: true

module Rooq
  module Dialect
    class PostgreSQL < Base
      def render_select(query)
        params = []
        sql_parts = []

        # CTEs (WITH clause)
        unless query.ctes.empty?
          cte_parts = query.ctes.map { |cte| render_cte(cte, params) }
          recursive = query.ctes.any?(&:recursive) ? "RECURSIVE " : ""
          sql_parts << "WITH #{recursive}#{cte_parts.join(', ')}"
        end

        # SELECT clause
        distinct = query.distinct_flag ? "DISTINCT " : ""
        fields = render_select_fields(query.selected_fields, params)
        sql_parts << "SELECT #{distinct}#{fields}"

        # FROM clause
        if query.from_table
          from_sql = render_from_source(query.from_table, params)
          from_sql = "#{from_sql} AS #{query.table_alias}" if query.table_alias
          sql_parts << "FROM #{from_sql}"
        end

        # JOIN clauses
        query.joins.each do |join|
          sql_parts << render_join(join, params)
        end

        # WHERE clause
        if query.conditions
          condition_sql = render_condition(query.conditions, params)
          sql_parts << "WHERE #{condition_sql}"
        end

        # GROUP BY clause
        unless query.group_by_fields.empty?
          group_parts = query.group_by_fields.map { |f| render_group_by_item(f, params) }
          sql_parts << "GROUP BY #{group_parts.join(', ')}"
        end

        # HAVING clause
        if query.having_condition
          having_sql = render_condition(query.having_condition, params)
          sql_parts << "HAVING #{having_sql}"
        end

        # ORDER BY clause
        unless query.order_specs.empty?
          order_parts = query.order_specs.map { |spec| render_order_spec(spec, params) }
          sql_parts << "ORDER BY #{order_parts.join(', ')}"
        end

        # LIMIT clause
        sql_parts << "LIMIT #{query.limit_value}" if query.limit_value

        # OFFSET clause
        sql_parts << "OFFSET #{query.offset_value}" if query.offset_value

        # FOR UPDATE
        sql_parts << "FOR UPDATE" if query.for_update_flag

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
          fields = render_select_fields(query.returning_fields, params)
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
          fields = render_select_fields(query.returning_fields, params)
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
          fields = render_select_fields(query.returning_fields, params)
          sql_parts << "RETURNING #{fields}"
        end

        RenderedQuery.new(sql_parts.join(" "), params)
      end

      def render_set_operation(op)
        params = []
        sql = render_set_operation_sql(op, params)
        RenderedQuery.new(sql, params)
      end

      def render_ordered_set_operation(op)
        params = []
        sql_parts = []

        sql_parts << "(#{render_set_operation_sql(op.set_operation, params)})"

        unless op.order_specs.empty?
          order_parts = op.order_specs.map { |spec| render_order_spec(spec, params) }
          sql_parts << "ORDER BY #{order_parts.join(', ')}"
        end

        sql_parts << "LIMIT #{op.limit_value}" if op.limit_value
        sql_parts << "OFFSET #{op.offset_value}" if op.offset_value

        RenderedQuery.new(sql_parts.join(" "), params)
      end

      def render_condition(condition, params)
        case condition
        when Condition
          render_simple_condition(condition, params)
        when CombinedCondition
          render_combined_condition(condition, params)
        when ExistsCondition
          render_exists_condition(condition, params)
        else
          raise ArgumentError, "Unknown condition type: #{condition.class}"
        end
      end

      private

      def render_set_operation_sql(op, params)
        left_sql = case op.left
                   when DSL::SetOperation
                     render_set_operation_sql(op.left, params)
                   else
                     render_select(op.left).tap { |r| params.concat(r.params) }.sql
                   end

        # Track offset for renumbering right query's placeholders
        param_offset = params.length

        right_result = case op.right
                       when DSL::SetOperation
                         render_set_operation_sql(op.right, params)
                       else
                         render_select(op.right).tap { |r| params.concat(r.params) }
                       end

        # Renumber placeholders in right query if needed
        right_sql = case right_result
                    when RenderedQuery
                      renumber_placeholders(right_result.sql, param_offset)
                    else
                      right_result
                    end

        operator = op.operator.to_s.upcase
        operator = "#{operator} ALL" if op.all

        "(#{left_sql}) #{operator} (#{right_sql})"
      end

      def renumber_placeholders(sql, offset)
        return sql if offset == 0
        sql.gsub(/\$(\d+)/) { |_| "$#{Regexp.last_match(1).to_i + offset}" }
      end

      def render_cte(cte, params)
        subquery_result = render_select(cte.query)
        params.concat(subquery_result.params)
        "#{cte.name} AS (#{subquery_result.sql})"
      end

      def render_select_fields(fields, params)
        fields.map { |f| render_select_field(f, params) }.join(", ")
      end

      def render_select_field(field, params)
        case field
        when AliasedExpression
          "#{render_expression(field.expression, params)} AS #{field.alias_name}"
        else
          render_expression(field, params)
        end
      end

      def render_expression(expr, params)
        case expr
        when Field
          expr.qualified_name
        when Literal
          if expr.value == :*
            "*"
          else
            params << expr.value
            "$#{params.length}"
          end
        when FunctionCall
          render_function_call(expr, params)
        when WindowFunction
          render_window_function(expr, params)
        when CaseExpression
          render_case_expression(expr, params)
        when CastExpression
          render_cast_expression(expr, params)
        when ArithmeticExpression
          render_arithmetic_expression(expr, params)
        when DSL::Subquery
          "(#{render_select(expr.query).tap { |r| params.concat(r.params) }.sql})"
        when Symbol
          expr.to_s
        else
          expr.to_s
        end
      end

      def render_function_call(func, params)
        args = func.arguments.map { |arg| render_expression(arg, params) }
        distinct = func.distinct ? "DISTINCT " : ""
        "#{func.name.to_s.upcase}(#{distinct}#{args.join(', ')})"
      end

      def render_window_function(wf, params)
        func_sql = render_expression(wf.function, params)
        over_parts = []

        unless wf.partition_by.empty?
          partition_exprs = wf.partition_by.map { |e| render_expression(e, params) }
          over_parts << "PARTITION BY #{partition_exprs.join(', ')}"
        end

        unless wf.order_by.empty?
          order_exprs = wf.order_by.map { |e| render_order_spec(e, params) }
          over_parts << "ORDER BY #{order_exprs.join(', ')}"
        end

        if wf.frame
          over_parts << render_window_frame(wf.frame)
        end

        "#{func_sql} OVER (#{over_parts.join(' ')})"
      end

      def render_window_frame(frame)
        type = frame.type.to_s.upcase
        start_bound = render_frame_bound(frame.start_bound)

        if frame.end_bound
          end_bound = render_frame_bound(frame.end_bound)
          "#{type} BETWEEN #{start_bound} AND #{end_bound}"
        else
          "#{type} #{start_bound}"
        end
      end

      def render_frame_bound(bound)
        case bound
        when :unbounded_preceding
          "UNBOUNDED PRECEDING"
        when :current_row
          "CURRENT ROW"
        when :unbounded_following
          "UNBOUNDED FOLLOWING"
        when Array
          direction, n = bound
          "#{n} #{direction.to_s.upcase}"
        else
          bound.to_s
        end
      end

      def render_case_expression(expr, params)
        parts = ["CASE"]

        expr.cases.each do |condition, result|
          cond_sql = render_condition(condition, params)
          result_sql = render_expression(result, params)
          parts << "WHEN #{cond_sql} THEN #{result_sql}"
        end

        if expr.else_result
          parts << "ELSE #{render_expression(expr.else_result, params)}"
        end

        parts << "END"
        parts.join(" ")
      end

      def render_cast_expression(expr, params)
        inner = render_expression(expr.expression, params)
        "CAST(#{inner} AS #{expr.target_type})"
      end

      def render_arithmetic_expression(expr, params)
        left = render_expression(expr.left, params)
        right = render_expression(expr.right, params)
        "(#{left} #{expr.operator} #{right})"
      end

      def render_from_source(source, params)
        case source
        when Table
          source.name.to_s
        when DSL::Subquery
          "(#{render_select(source.query).tap { |r| params.concat(r.params) }.sql}) AS #{source.alias_name}"
        when Symbol
          source.to_s
        else
          source.to_s
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
                    when :full then "FULL JOIN"
                    when :cross then "CROSS JOIN"
                    else raise ArgumentError, "Unknown join type: #{join.type}"
                    end

        table_sql = render_table_name(join.table)
        table_sql = "#{table_sql} AS #{join.table_alias}" if join.table_alias

        if join.using_columns
          columns = join.using_columns.map { |c| render_field_name(c) }
          "#{join_type} #{table_sql} USING (#{columns.join(', ')})"
        elsif join.condition
          condition_sql = render_condition(join.condition, params)
          "#{join_type} #{table_sql} ON #{condition_sql}"
        else
          join_type + " " + table_sql
        end
      end

      def render_group_by_item(item, params)
        case item
        when DSL::GroupingSets
          sets = item.sets.map { |s| "(#{s.map { |f| render_expression(f, params) }.join(', ')})" }
          "GROUPING SETS (#{sets.join(', ')})"
        when DSL::Cube
          fields = item.fields.map { |f| render_expression(f, params) }
          "CUBE (#{fields.join(', ')})"
        when DSL::Rollup
          fields = item.fields.map { |f| render_expression(f, params) }
          "ROLLUP (#{fields.join(', ')})"
        else
          render_expression(item, params)
        end
      end

      def render_order_spec(spec, params)
        expr_sql = render_expression(spec.expression, params)
        direction = spec.direction == :desc ? "DESC" : "ASC"
        result = "#{expr_sql} #{direction}"

        case spec.nulls
        when :first
          result += " NULLS FIRST"
        when :last
          result += " NULLS LAST"
        end

        result
      end

      def render_simple_condition(condition, params)
        expr_sql = render_expression(condition.expression, params)

        case condition.operator
        when :eq
          if condition.value.nil?
            "#{expr_sql} IS NULL"
          else
            params << condition.value
            "#{expr_sql} = $#{params.length}"
          end
        when :ne
          if condition.value.nil?
            "#{expr_sql} IS NOT NULL"
          else
            params << condition.value
            "#{expr_sql} <> $#{params.length}"
          end
        when :gt
          params << condition.value
          "#{expr_sql} > $#{params.length}"
        when :lt
          params << condition.value
          "#{expr_sql} < $#{params.length}"
        when :gte
          params << condition.value
          "#{expr_sql} >= $#{params.length}"
        when :lte
          params << condition.value
          "#{expr_sql} <= $#{params.length}"
        when :in
          if condition.value.is_a?(DSL::SelectQuery)
            subquery = render_select(condition.value)
            params.concat(subquery.params)
            "#{expr_sql} IN (#{subquery.sql})"
          else
            placeholders = condition.value.map do |v|
              params << v
              "$#{params.length}"
            end
            "#{expr_sql} IN (#{placeholders.join(', ')})"
          end
        when :like
          params << condition.value
          "#{expr_sql} LIKE $#{params.length}"
        when :ilike
          params << condition.value
          "#{expr_sql} ILIKE $#{params.length}"
        when :between
          params << condition.value[0]
          min_placeholder = "$#{params.length}"
          params << condition.value[1]
          max_placeholder = "$#{params.length}"
          "#{expr_sql} BETWEEN #{min_placeholder} AND #{max_placeholder}"
        when :is_null
          "#{expr_sql} IS NULL"
        when :is_not_null
          "#{expr_sql} IS NOT NULL"
        else
          raise ArgumentError, "Unknown operator: #{condition.operator}"
        end
      end

      def render_combined_condition(condition, params)
        parts = condition.conditions.map { |c| render_condition(c, params) }
        connector = condition.operator == :and ? " AND " : " OR "
        "(#{parts.join(connector)})"
      end

      def render_exists_condition(condition, params)
        subquery = render_select(condition.subquery)
        params.concat(subquery.params)
        prefix = condition.negated ? "NOT " : ""
        "#{prefix}EXISTS (#{subquery.sql})"
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
