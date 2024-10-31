class CheckModelsService
  MODEL_ROLES = %w[chat summarization embedding entity_extraction].freeze

  def execute
    missing_roles = detect_missing_roles
    return if missing_roles.empty?

    missing_roles.each { |role| select_default_for_role(role) }

    detect_missing_roles
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

  def warning_string_for(roles)
    "No model defined for roles #{roles.join(", ")}.

    Define a ModelConfig in Admin -> ModelConfigs and then click 'Use for <role>."
  end

  def defined_roles
    settings.map(&:key).map { |role| role.gsub(/_model$/, "") }
  end

  def settings
    Setting.where("key like ?", "%_model").where.not(value: nil)
  end
end
