# Production gets built-in agents from db:seed; the test schema load has no seeds.
RSpec.configure do |config|
  config.before(:suite) { Agent.seed_built_ins! }
end
