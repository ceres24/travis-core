class ArtifactPartsAddFinal < ActiveRecord::Migration
  def change
    add_column :artifact_parts, :final, :boolean, default: false
  end
end
