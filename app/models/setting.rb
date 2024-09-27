class Setting < ApplicationRecord
  belongs_to :target, optional: true, polymorphic: true

  validates :key, uniqueness: { scope: :target }

  class << self
    def get(key, target: nil, default: nil)
      setting = find_by(key:, target:)

      if setting.nil?
        Setting.create!(key:, value: default, target:)

        default
      elsif setting.value.nil?
        setting.update!(value: default)

        setting.value
      else
        setting.value
      end
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

    def entity_extraction_model
      model_for("entity_extraction")
    end

    def model_for(role)
      model_id = find_by(key: "#{role}_model")&.value
      return if model_id.nil?

      ModelConfig.find(model_id)
    end
  end
end
