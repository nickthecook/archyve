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
admin_password = setting.call("ARCHYVE_ADMIN_PASSWORD", "password")

admin = User.find_or_initialize_by(email_address: admin_email)
admin.password = admin_password
admin.role = :admin
admin.save!
puts "Break-glass admin: #{admin.email_address}"

Agent.seed_built_ins!
puts "Built-in agents: #{Agent::BUILT_INS.keys.join(', ')}"

# Development-only cast for clicking around: one of each role, so every gate can
# be seen from both sides without editing anything.
if Rails.env.development?
  {
    "curator@archyve.local" => :curator,
    "visitor@archyve.local" => :visitor
  }.each do |email_address, role|
    user = User.find_or_initialize_by(email_address:)
    user.password = "password"
    user.role = role
    user.save!
    puts "Development #{role}: #{user.email_address}"
  end
end
