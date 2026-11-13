class CollectionGroupsController < ApplicationController
  require_role :admin

  before_action :set_collection

  def create
    grant = @collection.collection_groups.new(group_id: params[:group_id], access: params[:access])

    if grant.save
      redirect_to collection_people_path(@collection), notice: "#{grant.group.name} can now use #{@collection.name}."
    else
      redirect_to collection_people_path(@collection), alert: grant.errors.full_messages.to_sentence
    end
  end

  def update
    grant = @collection.collection_groups.find(params[:id])

    if grant.update(access: params[:access])
      redirect_to collection_people_path(@collection), notice: "Updated #{grant.group.name}."
    else
      redirect_to collection_people_path(@collection), alert: grant.errors.full_messages.to_sentence
    end
  end

  def destroy
    grant = @collection.collection_groups.find(params[:id])
    grant.destroy
    redirect_to collection_people_path(@collection), notice: "#{grant.group.name} can no longer use #{@collection.name}."
  end

  private

  def set_collection
    @collection = Collection.find_by!(slug: params[:collection_slug])
  end
end
