namespace :archyve do
  desc "Provision inference servers and models from ARCHYVE_INFERENCE"
  task provision_inference: :environment do
    Rails.logger.broadcast_to(ActiveSupport::Logger.new($stdout, level: :info)) unless Rails.env.production?
    Inference::Provisioner.call
  end
end
