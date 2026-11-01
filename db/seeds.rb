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

# The Ollama that OLLAMA_API_BASE points at, if anything does.
if (ollama_url = ENV["OLLAMA_API_BASE"].presence)
  server = InferenceServers::Ollama.find_or_initialize_by(name: "Ollama")

  if server.new_record?
    # The value carries the /v1 suffix RubyLLM needs; the row stores the root it
    # implies, and InferenceServers::Ollama puts the suffix back where it
    # belongs. Only set on create — an address edited since is the newer truth.
    server.base_url = ollama_url
    server.save!
    puts "Inference server: #{server.name} at #{server.base_url}"
  end

  # Seeding must not depend on the network, so the embedding model is written
  # from what we know rather than discovered — which is also why the id is
  # written out here rather than read from EMBEDDING_MODEL. That variable used
  # to be inert (RubyLLM's default was always overridden by an explicit
  # `model:`), and reviving the name with different meaning would be worse than
  # retiring it. To start on a different embedder, add it from the UI while the
  # corpus is still empty.
  if InferenceModel.embedding.none?
    embedding = server.inference_models.create!(
      name: "nomic-embed-text:v1.5",
      kind: :embedding,
      dimensions: Embedding::DIMENSIONS
    )
    puts "Embedding model: #{embedding.name} (#{embedding.dimensions}d)"
  end
end
