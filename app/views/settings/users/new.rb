# frozen_string_literal: true

class Views::Settings::Users::New < Views::Base
  def initialize(user:)
    @user = user
  end

  def view_template
    a(href: settings_users_path, class: "text-sm text-muted hover:text-fg transition-colors") { "← People" }

    header(class: "mt-3 mb-7") do
      h1(class: "text-2xl font-semibold tracking-tight") { "Add someone" }
      p(class: "mt-1 text-sm text-muted") { "There is no public sign-up — accounts are created here." }
    end

    render Views::Settings::Users::Form.new(user: @user)
  end

  private

  def page_title = "Add someone"
end
