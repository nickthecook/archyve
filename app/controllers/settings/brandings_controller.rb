module Settings
  class BrandingsController < ApplicationController
    require_role :admin

    PLACEHOLDERS = %w[ask_placeholder chat_placeholder].freeze

    def show
      render Views::Settings::Brandings::Show.new(brand: Brand.current)
    end

    def update
      Setting.transaction do
        update_logo
        Setting["brand.name"] = params[:name].to_s.strip
        PLACEHOLDERS.each { |field| update_placeholder(field) }
      end
      redirect_to settings_path, notice: "Saved."
    rescue ActiveRecord::RecordInvalid => e
      render Views::Settings::Brandings::Show.new(brand: submitted_brand, error: logo_error(e.record)),
        status: :unprocessable_content
    end

    private

    def update_logo
      if params[:logo].present?
        Setting["brand.logo"] = params[:logo]
      elsif params[:remove_logo] == "1"
        Setting.clear("brand.logo")
      end
    end

    # A placeholder can't usefully be empty, so blank means "back to the default".
    def update_placeholder(field)
      value = params[field].to_s.strip
      value.empty? ? Setting.clear("brand.#{field}") : Setting["brand.#{field}"] = value
    end

    # The logo is the only thing that can fail, and what was typed beside it
    # shouldn't be lost with it.
    def submitted_brand
      Brand.current.with(name: params[:name].to_s.strip, **PLACEHOLDERS.to_h { [it.to_sym, params[it].to_s.strip] })
    end

    def logo_error(record)
      "The logo #{record.errors.messages_for(:file).to_sentence}."
    end
  end
end
