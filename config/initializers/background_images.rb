dark_files = Dir.glob(Rails.public_path.join('backgrounds/dark/*').to_s)
Rails.configuration.dark_backgrounds = dark_files.map do |file|
  "/backgrounds/dark/#{File.basename(file)}"
end

# still need a way to tell if the app is in light mode
light_files = Dir.glob(Rails.public_path.join('backgrounds/light/*').to_s)
Rails.configuration.light_backgrounds = light_files.map do |file|
  "/backgrounds/light/#{File.basename(file)}"
end
