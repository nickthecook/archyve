Rails.configuration.version = if Dir.exist?('.git')
  `git describe --tags`.strip
else
  # make this calculated in production, or at least have tests or something else to detect drift from git tag
  "v1.20.0"
end
