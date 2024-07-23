class ForceCreateNodesentityUuidConstraint < ActiveGraph::Migrations::Base
  def up
    add_constraint :"Nodes::entity", :uuid, force: true
  end

  def down
    drop_constraint :"Nodes::entity", :uuid
  end
end
