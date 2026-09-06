class ChatController < ApplicationController
  def index
    render Views::Chat::Index.new
  end
end
