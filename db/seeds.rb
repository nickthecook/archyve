# Idempotent by construction — safe to run on every deploy and after every
# `db:reset`. Run with `ops rails db:seed`, which loads secrets.ejson.
#
# The break-glass admin always exists, and its password is always reset to match
# the environment. That is deliberate: losing access to Archyve should never be
# worse than reading secrets.ejson. It matters more once Keycloak owns normal
# sign-in — when SSO is down, this account is the way in.

# Required outside development; defaulted inside it so a fresh clone can be
# seeded and signed into without setting anything up first. The default is
# gated strictly on development so a production deploy can't quietly come up
# with a published password.
setting = lambda do |name, development_default|
  value = ENV[name].presence
  next value if value
  next development_default if Rails.env.development?

  raise "#{name} must be set to seed #{Rails.env} — put it in config/#{Rails.env}/" \
        "#{name.end_with?('PASSWORD') ? 'secrets.ejson' : 'config.yml'}"
end

admin_email = setting.call("ARCHYVE_ADMIN_EMAIL", "admin@archyve.local")
admin_password = setting.call("ARCHYVE_ADMIN_PASSWORD", "archyve-development-password")

admin = User.find_or_initialize_by(email_address: admin_email)
admin.password = admin_password
admin.save!
puts "Break-glass admin: #{admin.email_address}"

# Development-only cast for clicking around. Named for the roles they will hold
# once roles land, so this list doesn't need rewriting then — for now every
# account is equal.
if Rails.env.development?
  {
    "operator@archyve.local" => "archyve-development-password",
    "user@archyve.local" => "archyve-development-password"
  }.each do |email_address, password|
    user = User.find_or_initialize_by(email_address:)
    user.password = password
    user.save!
    puts "Development user: #{user.email_address}"
  end
end
