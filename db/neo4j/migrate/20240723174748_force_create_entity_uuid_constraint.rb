class ForceCreateEntityUuidConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :Entity, :uuid, force: true
  end

  def down
    drop_constraint :Entity, :uuid
  end
end
