require 'metriks'

class Artifact::Log < Artifact
  class << self
    AGGREGATE_SQL = %(
      UPDATE artifacts
         SET aggregated_at = ?, content = (
               SELECT array_to_string(array_agg(artifact_parts.content), '')
               FROM artifact_parts
               WHERE artifacts.id = ?
             )
       WHERE artifacts.id = ?
    )

    def append(id, chars, sequence = nil)
      meter do
        if sequence && Travis::Features.feature_active?(:log_aggregation)
          Artifact::Part.create!(:artifact_id => id, :content => filter(chars), :sequence => sequence)
        else
          update_all(["content = COALESCE(content, '') || ?", filter(chars)], ["job_id = ?", id])
        end
      end
    end

    def aggregate(id)
      connection.execute(sanitize_sql([AGGREGATE_SQL, Time.now, id, id]))
      Artifact::Part.delete_all(:artifact_id => id)
    end

    private

      def filter(chars)
        # postgres seems to have issues with null chars
        chars.gsub("\0", '')
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
    parts.order(:id).select(:content).map(&:content).join || ''
  end
end
