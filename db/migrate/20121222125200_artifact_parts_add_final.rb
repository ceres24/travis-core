class ArtifactPartsAddFinal < ActiveRecord::Migration
  def change
    add_column :artifact_parts, :final, :timestamp
    add_column :artifact_parts, :created_at, :timestamp
  end
end
