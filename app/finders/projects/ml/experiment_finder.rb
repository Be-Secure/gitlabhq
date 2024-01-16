# frozen_string_literal: true

module Projects
  module Ml
    class ExperimentFinder
      include Gitlab::Utils::StrongMemoize

      VALID_ORDER_BY = %w[name created_at updated_at id].freeze
      VALID_SORT = %w[asc desc].freeze

      def initialize(project, params = {})
        @project = project
        @params = params
      end

      def execute
        relation
      end

      private

      def relation
        @experiments = ::Ml::Experiment
            .by_project(project)
            .including_project

        ordered
      end

      def ordered
        order_by = valid_or_default(params[:order_by]&.downcase, VALID_ORDER_BY, 'id')
        sort = valid_or_default(params[:sort]&.downcase, VALID_SORT, 'desc')

        experiments.order_by("#{order_by}_#{sort}").with_order_id_desc
      end

      def valid_or_default(value, valid_values, default)
        return value if valid_values.include?(value)

        default
      end

      attr_reader :params, :project, :experiments
    end
  end
end
