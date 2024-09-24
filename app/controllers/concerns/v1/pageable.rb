module V1
  module Pageable
    include Pagy::Backend

    def page_data
      { page:, items:, total: @pagy.count, pages: @pagy.pages, in: @pagy.in }
    end

    def page
      params[:page]&.to_i || 1
    end

    def items
      params[:count]&.to_i || 20
    end
  end
end
