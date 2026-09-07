# Signs a request spec in the way a person does — by posting the sign-in form —
# so specs exercise the same cookie and Session row the app uses. Stubbing
# Current.user instead would leave `require_authentication` untested everywhere.
module AuthenticationHelpers
  # Shared with spec/factories/users.rb so the two can't drift; a factory-built
  # user is always signable-in with this.
  PASSWORD = "sufficiently-long-password".freeze

  def sign_in(user = create(:user), password: PASSWORD)
    post session_path, params: { email_address: user.email_address, password: }
    user
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request

  # The whole app is behind the sign-in wall, so a request spec that doesn't
  # sign in is testing the redirect, not the page. Signing in by default keeps
  # that out of every example; tag `unauthenticated: true` to opt out and
  # exercise the signed-out path deliberately.
  #
  # Safe against the sessions#create rate limit because the test cache is
  # :null_store (config/environments/test.rb), so rate_limit never trips.
  config.before(type: :request) do |example|
    sign_in unless example.metadata[:unauthenticated]
  end
end
