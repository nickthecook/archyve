class SourceGroupsController < ApplicationController
  require_role :admin

  before_action :set_source

  def create
    grant = @source.source_groups.new(group_id: params[:group_id], access: params[:access])

    if grant.save
      redirect_to source_people_path(@source), notice: "#{grant.group.name} can now manage #{@source.name}."
    else
      redirect_to source_people_path(@source), alert: grant.errors.full_messages.to_sentence
    end
  end

  def update
    grant = @source.source_groups.find(params[:id])

    if grant.update(access: params[:access])
      redirect_to source_people_path(@source), notice: "Updated #{grant.group.name}."
    else
      redirect_to source_people_path(@source), alert: grant.errors.full_messages.to_sentence
    end
  end

  def destroy
    grant = @source.source_groups.find(params[:id])
    grant.destroy
    redirect_to source_people_path(@source), notice: "#{grant.group.name} can no longer manage #{@source.name}."
  end

  private

  def set_source
    @source = Source.find(params[:source_id])
  end
end
