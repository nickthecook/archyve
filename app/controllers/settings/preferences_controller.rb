module Settings
  # The on/off switches on the settings index. A flip is the whole interaction —
  # there is no form to save — so the response swaps the one row back rather
  # than re-rendering the page under the pointer that clicked it.
  class PreferencesController < ApplicationController
    require_role :admin

    def update
      key = permitted_key
      return redirect_to(settings_path, alert: "No such setting.") if key.nil?

      value = ActiveModel::Type::Boolean.new.cast(params[:value])
      Setting[key] = value

      respond_to do |format|
        format.turbo_stream { render turbo_stream: swap(key, value) }
        format.html { redirect_to settings_path }
      end
    end

    private

    # Setting[]= already rejects a key it doesn't know, but nothing there stops
    # a crafted request writing "true" into an integer setting.
    def permitted_key = params[:key].presence_in(Setting.toggles.keys)

    # render_to_string rather than the component's own #call: the form needs
    # route helpers, and those want a view context the component has no way to
    # build for itself.
    def swap(key, value)
      turbo_stream.replace(
        Views::Settings::Toggle.dom_id(key),
        html: render_to_string(Views::Settings::Toggle.new(key: key, on: value))
      )
    end
  end
end
