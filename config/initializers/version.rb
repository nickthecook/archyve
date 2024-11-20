Rails.configuration.version = if Dir.exist?('.git')
  `git describe --tags`.strip
else
  # TODO: make this calculated in production, or at least have tests or something else to detect drift from git tag
  "v1.20.3"
end
