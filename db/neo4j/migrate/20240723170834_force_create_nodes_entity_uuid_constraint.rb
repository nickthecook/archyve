class ForceCreateNodesEntityUuidConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :"Nodes::Entity", :uuid, force: true
  end

  def down
    drop_constraint :"Nodes::Entity", :uuid
  end
end
