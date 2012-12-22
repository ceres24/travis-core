require 'metriks'

class Artifact::Log < Artifact
  # TODO remove this once we know aggregation works fine and the worker passes a :final flag
  FINAL = 'Done. Build script exited with:'

  class << self
    def append(job_id, chars, number = nil, final = false)
      meter do
        if Travis::Features.feature_active?(:log_aggregation)
          id = Artifact::Log.where(job_id: job_id).select(:id).first.id
          Artifact::Part.create!(artifact_id: id, content: filter(chars), number: number, final: final || final?(chars))
        else
          update_all(["content = COALESCE(content, '') || ?", filter(chars)], ["job_id = ?", job_id])
        end
      end
    end

    def aggregate(id)
      ActiveRecord::Base.transaction do
        Artifact::Part.aggregate(id)
        Artifact::Part.delete_all(artifact_id: id)
      end
    end

    private

      def filter(chars)
        # postgres seems to have issues with null chars
        chars.gsub("\0", '')
      end

      def final?(chars)
        chars.include?(FINAL)
      end

      # TODO should be done by Travis::LogSubscriber::ActiveRecordMetrics but i can't get it
      # to be picked up outside of rails
      def meter(&block)
        Metriks.timer('active_record.log_updates').time(&block)
      end
  end

  has_many :parts, :class_name => 'Artifact::Part', :foreign_key => :artifact_id

  def content
    if Travis::Features.feature_active?(:log_aggregation)
      aggregated? ? read_attribute(:content) : aggregated_content
    else
      read_attribute(:content)
    end
  end

  def aggregated?
    !!aggregated_at
  end

  def aggregated_content
    self.class.connection.select_value(self.class.send(:sanitize_sql, [Part::AGGREGATE_SELECT_SQL, id]))
  end
end
