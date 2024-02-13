# frozen_string_literal: true

module Gitlab
  module InternalEvents
    UnknownEventError = Class.new(StandardError)
    InvalidPropertyError = Class.new(StandardError)
    InvalidPropertyTypeError = Class.new(StandardError)

    SNOWPLOW_EMITTER_BUFFER_SIZE = 100

    class << self
      include Gitlab::Tracking::Helpers
      include Gitlab::Utils::StrongMemoize

      def track_event(event_name, category: nil, send_snowplow_event: true, **kwargs)
        raise UnknownEventError, "Unknown event: #{event_name}" unless EventDefinitions.known_event?(event_name)

        validate_property!(kwargs, :user, User)
        validate_property!(kwargs, :namespace, Namespaces::UserNamespace, Group)
        validate_property!(kwargs, :project, Project)

        project = kwargs[:project]
        kwargs[:namespace] ||= project.namespace if project

        increase_total_counter(event_name)
        increase_weekly_total_counter(event_name)
        update_unique_counters(event_name, kwargs)
        trigger_snowplow_event(event_name, category, kwargs) if send_snowplow_event

        if Feature.enabled?(:internal_events_for_product_analytics)
          send_application_instrumentation_event(event_name, kwargs)
        end
      rescue StandardError => e
        extra = {}
        kwargs.each_key do |k|
          extra[k] = kwargs[k].is_a?(::ApplicationRecord) ? kwargs[k].try(:id) : kwargs[k]
        end
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e, event_name: event_name, kwargs: extra)
        nil
      end

      private

      def validate_property!(kwargs, property_name, *class_names)
        return unless kwargs.has_key?(property_name)
        return if kwargs[property_name].nil?
        return if class_names.include?(kwargs[property_name].class)

        raise InvalidPropertyTypeError, "#{property_name} should be an instance of #{class_names.join(', ')}"
      end

      def increase_total_counter(event_name)
        redis_counter_key =
          Gitlab::Usage::Metrics::Instrumentations::TotalCountMetric.redis_key(event_name)
        Gitlab::Redis::SharedState.with { |redis| redis.incr(redis_counter_key) }
      end

      def increase_weekly_total_counter(event_name)
        redis_counter_key =
          Gitlab::Usage::Metrics::Instrumentations::TotalCountMetric.redis_key(event_name, Date.today)
        Gitlab::Redis::SharedState.with { |redis| redis.incr(redis_counter_key) }
      end

      def update_unique_counters(event_name, kwargs)
        unique_properties = EventDefinitions.unique_properties(event_name)
        return if unique_properties.empty?

        if Feature.disabled?(:redis_hll_property_name_tracking, type: :wip)
          unique_properties = handle_legacy_property_names(unique_properties, event_name)
        end

        unique_properties.each do |property_name|
          unless kwargs[property_name]
            message = "#{event_name} should be triggered with a named parameter '#{property_name}'."
            Gitlab::AppJsonLogger.warn(message: message)
            next
          end

          unique_value = kwargs[property_name].id

          UsageDataCounters::HLLRedisCounter.track_event(event_name, values: unique_value, property_name: property_name)
        end
      end

      def handle_legacy_property_names(unique_properties, event_name)
        # make sure we're not incrementing the user_id counter with project_id value
        return [:user] if event_name.to_s == 'user_visited_dashboard'

        return unique_properties if unique_properties.length == 1

        # in case a new event got defined with multiple unique_properties, raise an error
        raise Gitlab::InternalEvents::EventDefinitions::InvalidMetricConfiguration,
          "The same event cannot have several unique properties defined. " \
          "Event: #{event_name}, unique values: #{unique_properties}"
      end

      def trigger_snowplow_event(event_name, category, kwargs)
        user = kwargs[:user]
        project = kwargs[:project]
        namespace = kwargs[:namespace]

        standard_context = Tracking::StandardContext.new(
          project_id: project&.id,
          user_id: user&.id,
          namespace_id: namespace&.id,
          plan_name: namespace&.actual_plan_name
        ).to_context

        service_ping_context = Tracking::ServicePingContext.new(
          data_source: :redis_hll,
          event: event_name
        ).to_context

        track_struct_event(event_name, category, contexts: [standard_context, service_ping_context])
      end

      def track_struct_event(event_name, category, contexts:)
        category ||= 'InternalEventTracking'
        tracker = Gitlab::Tracking.tracker
        tracker.event(category, event_name, context: contexts)
      rescue StandardError => error
        Gitlab::ErrorTracking
          .track_and_raise_for_dev_exception(error, snowplow_category: category, snowplow_action: event_name)
      end

      def send_application_instrumentation_event(event_name, kwargs)
        return if gitlab_sdk_client.nil?

        user = kwargs[:user]

        gitlab_sdk_client.identify(user&.id)
        gitlab_sdk_client.track(event_name, { project_id: kwargs[:project]&.id, namespace_id: kwargs[:namespace]&.id })
      end

      def gitlab_sdk_client
        app_id = ENV['GITLAB_ANALYTICS_ID']
        host = ENV['GITLAB_ANALYTICS_URL']

        return unless app_id.present? && host.present?

        GitlabSDK::Client.new(app_id: app_id, host: host, buffer_size: SNOWPLOW_EMITTER_BUFFER_SIZE)
      end
      strong_memoize_attr :gitlab_sdk_client
    end
  end
end
