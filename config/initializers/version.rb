Rails.configuration.version = if Dir.exist?('.git')
  `git describe --tags`.strip
else
  "1.15.0"
end
