# frozen_string_literal: true

module BulkImports
  class PipelineWorker
    include ApplicationWorker
    include ExclusiveLeaseGuard

    FILE_EXTRACTION_PIPELINE_PERFORM_DELAY = 10.seconds

    DEFER_ON_HEALTH_DELAY = 5.minutes

    data_consistency :always
    feature_category :importers
    sidekiq_options dead: false, retry: 3
    worker_has_external_dependencies!
    deduplicate :until_executing
    worker_resource_boundary :memory
    idempotent!

    version 2

    sidekiq_retries_exhausted do |msg, exception|
      new.perform_failure(msg['args'][0], msg['args'][2], exception)
    end

    defer_on_database_health_signal(:gitlab_main, [], DEFER_ON_HEALTH_DELAY) do |job_args, schema, tables|
      pipeline_tracker = ::BulkImports::Tracker.find(job_args.first)
      pipeline_schema = ::BulkImports::PipelineSchemaInfo.new(
        pipeline_tracker.pipeline_class,
        pipeline_tracker.entity.portable_class
      )

      if pipeline_schema.db_schema && pipeline_schema.db_table
        schema = pipeline_schema.db_schema
        tables = [pipeline_schema.db_table]
      end

      [schema, tables]
    end

    def self.defer_on_database_health_signal?
      Feature.enabled?(:bulk_import_deferred_workers)
    end

    # Keep _stage parameter for backwards compatibility.
    def perform(pipeline_tracker_id, _stage, entity_id)
      @entity = ::BulkImports::Entity.find(entity_id)
      @pipeline_tracker = ::BulkImports::Tracker.find(pipeline_tracker_id)

      log_extra_metadata_on_done(:pipeline_class, @pipeline_tracker.pipeline_name)

      try_obtain_lease do
        if pipeline_tracker.enqueued? || pipeline_tracker.started?
          logger.info(log_attributes(message: 'Pipeline starting'))

          run
        end
      end
    end

    def perform_failure(pipeline_tracker_id, entity_id, exception)
      @entity = ::BulkImports::Entity.find(entity_id)
      @pipeline_tracker = ::BulkImports::Tracker.find(pipeline_tracker_id)

      fail_tracker(exception)
    end

    private

    attr_reader :pipeline_tracker, :entity

    def run
      return skip_tracker if entity.failed?

      raise(Pipeline::FailedError, "Export from source instance failed: #{export_status.error}") if export_failed?
      raise(Pipeline::ExpiredError, 'Empty export status on source instance') if empty_export_timeout?

      return re_enqueue if export_empty? || export_started?

      if file_extraction_pipeline? && export_status.batched?
        log_extra_metadata_on_done(:batched, true)

        pipeline_tracker.update!(status_event: 'start', jid: jid, batched: true)

        return pipeline_tracker.finish! if export_status.batches_count < 1

        enqueue_batches
      else
        log_extra_metadata_on_done(:batched, false)

        pipeline_tracker.update!(status_event: 'start', jid: jid)
        pipeline_tracker.pipeline_class.new(context).run
        pipeline_tracker.finish!
      end
    rescue BulkImports::RetryPipelineError => e
      retry_tracker(e)
    end

    def source_version
      entity.bulk_import.source_version_info.to_s
    end

    def fail_tracker(exception)
      pipeline_tracker.update!(status_event: 'fail_op', jid: jid)

      log_exception(exception, log_attributes(message: 'Pipeline failed'))

      Gitlab::ErrorTracking.track_exception(exception, log_attributes)

      BulkImports::Failure.create(
        bulk_import_entity_id: entity.id,
        pipeline_class: pipeline_tracker.pipeline_name,
        pipeline_step: 'pipeline_worker_run',
        exception_class: exception.class.to_s,
        exception_message: exception.message,
        correlation_id_value: Labkit::Correlation::CorrelationId.current_or_new_id
      )
    end

    def logger
      @logger ||= Logger.build
    end

    def re_enqueue(delay = FILE_EXTRACTION_PIPELINE_PERFORM_DELAY)
      log_extra_metadata_on_done(:re_enqueue, true)

      self.class.perform_in(
        delay,
        pipeline_tracker.id,
        pipeline_tracker.stage,
        entity.id
      )
    end

    def context
      @context ||= ::BulkImports::Pipeline::Context.new(pipeline_tracker)
    end

    def export_status
      @export_status ||= ExportStatus.new(pipeline_tracker, pipeline_tracker.pipeline_class.relation)
    end

    def file_extraction_pipeline?
      pipeline_tracker.file_extraction_pipeline?
    end

    def empty_export_timeout?
      export_empty? && time_since_tracker_created > Pipeline::EMPTY_EXPORT_STATUS_TIMEOUT
    end

    def export_failed?
      return false unless file_extraction_pipeline?

      export_status.failed?
    end

    def export_started?
      return false unless file_extraction_pipeline?

      export_status.started?
    end

    def export_empty?
      return false unless file_extraction_pipeline?

      export_status.empty?
    end

    def retry_tracker(exception)
      log_exception(exception, log_attributes(message: "Retrying pipeline"))

      pipeline_tracker.update!(status_event: 'retry', jid: jid)

      re_enqueue(exception.retry_delay)
    end

    def skip_tracker
      logger.info(log_attributes(message: 'Skipping pipeline due to failed entity'))

      pipeline_tracker.update!(status_event: 'skip', jid: jid)
    end

    def log_attributes(extra = {})
      structured_payload(
        {
          bulk_import_entity_id: entity.id,
          bulk_import_id: entity.bulk_import_id,
          bulk_import_entity_type: entity.source_type,
          source_full_path: entity.source_full_path,
          pipeline_tracker_id: pipeline_tracker.id,
          pipeline_class: pipeline_tracker.pipeline_name,
          pipeline_tracker_state: pipeline_tracker.human_status_name,
          source_version: source_version,
          importer: Logger::IMPORTER_NAME
        }.merge(extra)
      )
    end

    def log_exception(exception, payload)
      Gitlab::ExceptionLogFormatter.format!(exception, payload)

      logger.error(structured_payload(payload))
    end

    def time_since_tracker_created
      Time.zone.now - (pipeline_tracker.created_at || entity.created_at)
    end

    def lease_timeout
      30
    end

    def lease_key
      "gitlab:bulk_imports:pipeline_worker:#{pipeline_tracker.id}"
    end

    def enqueue_batches
      1.upto(export_status.batches_count) do |batch_number|
        batch = pipeline_tracker.batches.find_or_create_by!(batch_number: batch_number) # rubocop:disable CodeReuse/ActiveRecord

        ::BulkImports::PipelineBatchWorker.perform_async(batch.id)
      end
    end
  end
end
