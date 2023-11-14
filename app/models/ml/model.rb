# frozen_string_literal: true

module Ml
  class Model < ApplicationRecord
    include Presentable
    include Sortable

    validates :project, :default_experiment, presence: true
    validates :name,
      format: Gitlab::Regex.ml_model_name_regex,
      uniqueness: { scope: :project },
      presence: true,
      length: { maximum: 255 }

    validate :valid_default_experiment?

    has_one :default_experiment, class_name: 'Ml::Experiment'
    belongs_to :project
    belongs_to :user
    has_many :versions, class_name: 'Ml::ModelVersion'
    has_many :metadata, class_name: 'Ml::ModelMetadata'
    has_one :latest_version, -> { latest_by_model }, class_name: 'Ml::ModelVersion', inverse_of: :model

    scope :including_latest_version, -> { includes(:latest_version) }
    scope :including_project, -> { includes(:project) }
    scope :with_version_count, -> {
      left_outer_joins(:versions)
        .select("ml_models.*, count(ml_model_versions.id) as version_count")
        .group(:id)
    }
    scope :by_name, ->(name) { where("ml_models.name LIKE ?", "%#{sanitize_sql_like(name)}%") } # rubocop:disable GitlabSecurity/SqlInjection
    scope :by_project, ->(project) { where(project_id: project.id) }

    def valid_default_experiment?
      return unless default_experiment

      errors.add(:default_experiment) unless default_experiment.name == name
      errors.add(:default_experiment) unless default_experiment.project_id == project_id
    end

    def self.by_project_id_and_id(project_id, id)
      find_by(project_id: project_id, id: id)
    end

    def self.by_project_id_and_name(project_id, name)
      find_by(project_id: project_id, name: name)
    end
  end
end
