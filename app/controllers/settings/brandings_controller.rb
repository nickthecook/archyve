module Settings
  class BrandingsController < ApplicationController
    require_role :admin

    # Unlike the name, none of these is worth storing blank, so blank means
    # "back to the default".
    DEFAULTABLE = %w[ask_placeholder chat_placeholder disclaimer].freeze
    IMAGES = { "logo" => "logo", "landing_image" => "landing image" }.freeze

    def show
      render Views::Settings::Brandings::Show.new(brand: Brand.current)
    end

    def update
      Setting.transaction do
        IMAGES.each_key { |field| update_image(field) }
        store("name", params[:name].to_s.strip)
        DEFAULTABLE.each { |field| store(field, params[field].to_s.strip.presence) }
        store("corridor", params[:corridor] == "1")
      end
      redirect_to settings_path, notice: "Saved."
    rescue ActiveRecord::RecordInvalid => e
      render Views::Settings::Brandings::Show.new(brand: submitted_brand, error: image_error(e.record)),
        status: :unprocessable_content
    end

    private

    def update_image(field)
      if params[field].present?
        Setting["brand.#{field}"] = params[field]
      elsif params["remove_#{field}"] == "1"
        Setting.clear("brand.#{field}")
      end
    end

    # A value equal to its default is stored as no row, so Settings can tell
    # whether the branding has really been changed.
    def store(field, value)
      key = "brand.#{field}"
      if value.nil? || value == Setting::DEFINITIONS.fetch(key).default_value
        Setting.clear(key)
      else
        Setting[key] = value
      end
    end

    # Only an image can fail, and what was typed beside it shouldn't be lost with it.
    def submitted_brand
      Brand.current.with(
        name: params[:name].to_s.strip,
        corridor: params[:corridor] == "1",
        **DEFAULTABLE.to_h { [it.to_sym, params[it].to_s.strip] }
      )
    end

    def image_error(record)
      "The #{IMAGES.fetch(record.key.delete_prefix('brand.'))} #{record.errors.messages_for(:file).to_sentence}."
    end
  end
end
