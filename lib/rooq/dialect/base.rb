# frozen_string_literal: true

module Rooq
  module Dialect
    class Base
      def render_select(query)
        raise NotImplementedError
      end

      def render_insert(query)
        raise NotImplementedError
      end

      def render_update(query)
        raise NotImplementedError
      end

      def render_delete(query)
        raise NotImplementedError
      end

      def render_condition(condition, params)
        raise NotImplementedError
      end
    end
  end
end
