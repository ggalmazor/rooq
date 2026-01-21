# frozen_string_literal: true

module Rooq
  class Executor
    attr_reader :connection, :dialect, :hooks

    def initialize(connection, dialect: Dialect::PostgreSQL.new)
      @connection = connection
      @dialect = dialect
      @hooks = ExecutorHooks.new
    end

    def execute(query)
      rendered = query.to_sql(@dialect)

      hooks.before_execute&.call(rendered)

      result = @connection.exec_params(rendered.sql, rendered.params)

      hooks.after_execute&.call(rendered, result)

      result
    end

    def fetch_one(query)
      result = execute(query)
      return nil if result.ntuples.zero?

      result[0]
    end

    def fetch_all(query)
      result = execute(query)
      result.to_a
    end

    def on_before_execute(&block)
      @hooks = @hooks.with_before_execute(block)
      self
    end

    def on_after_execute(&block)
      @hooks = @hooks.with_after_execute(block)
      self
    end
  end

  class ExecutorHooks
    attr_reader :before_execute, :after_execute

    def initialize(before_execute: nil, after_execute: nil)
      @before_execute = before_execute
      @after_execute = after_execute
      freeze
    end

    def with_before_execute(block)
      ExecutorHooks.new(before_execute: block, after_execute: @after_execute)
    end

    def with_after_execute(block)
      ExecutorHooks.new(before_execute: @before_execute, after_execute: block)
    end
  end
end
