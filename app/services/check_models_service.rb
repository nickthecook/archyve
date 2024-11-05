class CheckModelsService
  MODEL_ROLES = %w[chat summarization embedding].freeze

  def execute
    missing_roles = detect_missing_roles
    return if missing_roles.empty?

    missing_roles
  end

  private

  def select_default_for_role(role)
    if role == "embedding"
      Setting.get("#{role}_model", default: ModelConfig.available.embedding.last&.id)
    else
      Setting.get("#{role}_model", default: ModelConfig.available.generation.last&.id)
    end
  end

  def detect_missing_roles
    MODEL_ROLES - defined_roles
  end

  def defined_roles
    settings.map(&:key).map { |role| role.gsub(/_model$/, "") }
  end

  def settings
    Setting.where("key like ?", "%_model").where.not(value: nil)
  end
end
