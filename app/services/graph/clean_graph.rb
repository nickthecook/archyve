module Graph
  class CleanGraph
    def clean!
      Nodes::Entity.find_each(&:destroy)
    end
  end
end
