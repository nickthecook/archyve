class Setting < ApplicationRecord
  belongs_to :target, optional: true, polymorphic: true

  # validates :key, uniqueness: { scope: :target }

  class << self
    def ensure_exists(key, target: nil, default: nil)
      setting = find_by(key:, target:)

      if setting.nil?
        setting = Setting.create!(key:, value: default, target:)
      elsif setting.value.nil?
        setting.update!(value: default)
      end

      setting
    end

    def get(*args, **kwargs)
      ensure_exists(*args, **kwargs).value
    end

    def set(key, value, target: nil)
      find_or_create_by(key:, target:).update!(value:)

      value
    end

    def chat_model
      model_for("chat")
    end

    def embedding_model
      model_for("embedding")
    end

    def summarization_model
      model_for("summarization")
    end

    def vision_model
      model_for("vision")
    end

    def entity_extraction_model
      model_for("entity_extraction")
    end

    def model_for(role)
      model_id = find_by(key: "#{role}_model")&.value
      return if model_id.nil?

      ModelConfig.available.find_by(id: model_id)
    end
  end
end
