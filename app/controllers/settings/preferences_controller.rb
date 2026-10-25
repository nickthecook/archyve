module Settings
  # The switches and numbers on the settings index. Editing is the whole
  # interaction — there is no page to come back to — so the response swaps the
  # one row back rather than re-rendering the page under the pointer that
  # clicked it.
  class PreferencesController < ApplicationController
    require_role :admin

    def update
      key = permitted_key
      return redirect_to(settings_path, alert: "No such setting.") if key.nil?

      value = value_for(key)
      return redirect_to(settings_path, alert: "That needs to be a number, 1 or more.") if value.nil?

      Setting[key] = value

      respond_to do |format|
        format.turbo_stream { render turbo_stream: swap(key, value) }
        format.html { redirect_to settings_path }
      end
    end

    private

    # Only the settings the index renders a control for. Setting[]= already
    # rejects a key it doesn't know, but nothing there stops a crafted request
    # writing "true" into an integer setting.
    def permitted_key
      params[:key].presence_in(Setting.toggles.keys + Views::Settings::Number::KEYS)
    end

    def value_for(key)
      return ActiveModel::Type::Boolean.new.cast(params[:value]) if Setting.toggles.key?(key)

      rounds
    end

    # Refused rather than coerced: "" and "none" both cast to 0, and a round
    # budget of 0 is a tool the model can never call.
    def rounds
      value = params[:value].to_s
      value.to_i if value.match?(/\A\s*\d+\s*\z/) && value.to_i.positive?
    end

    # render_to_string rather than the component's own #call: the form needs
    # route helpers, and those want a view context the component has no way to
    # build for itself.
    def swap(key, value)
      component = component_for(key, value)
      turbo_stream.replace(component.class.dom_id(key), html: render_to_string(component))
    end

    def component_for(key, value)
      if Setting.toggles.key?(key)
        Views::Settings::Toggle.new(key: key, on: value)
      else
        Views::Settings::Number.new(key: key, value: value)
      end
    end
  end
end
