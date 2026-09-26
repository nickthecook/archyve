class AddDescriptionToCollections < ActiveRecord::Migration[8.1]
  def change
    # What this collection is for, in the owner's words. Written for the chat
    # model as much as for the reader: "Ops" versus "Platform" is a coin flip,
    # and a model choosing where to look needs more than a name.
    add_column :collections, :description, :text
  end
end
