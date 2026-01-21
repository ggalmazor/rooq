# frozen_string_literal: true

require_relative "dsl/select_query"
require_relative "dsl/insert_query"
require_relative "dsl/update_query"
require_relative "dsl/delete_query"

module Rooq
  module DSL
    class << self
      def select(*fields)
        SelectQuery.new(fields)
      end

      def insert_into(table)
        InsertQuery.new(table)
      end

      def update(table)
        UpdateQuery.new(table)
      end

      def delete_from(table)
        DeleteQuery.new(table)
      end
    end
  end
end
