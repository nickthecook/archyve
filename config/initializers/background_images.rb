dark_files = Dir.glob(Rails.root.join("app/assets/images/backgrounds/dark/*").to_s)
Rails.configuration.dark_backgrounds = dark_files.map do |file|
  "/assets/backgrounds/dark/#{File.basename(file)}"
end

# still need a way to tell if the app is in light mode
light_files = Dir.glob(Rails.root.join("app/assets/images/backgrounds/light/*").to_s)
Rails.configuration.light_backgrounds = light_files.map do |file|
  "/assets/backgrounds/light/#{File.basename(file)}"
end
