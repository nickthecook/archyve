# frozen_string_literal: true

module Inference
  # Makes the provisioned inference servers and models match ARCHYVE_INFERENCE.
  # Run at boot by `bin/rails archyve:provision_inference`; the rules are in
  # docs/architecture.md. Never raises: every outcome is logged, and returned
  # so the caller can show it.
  class Provisioner
    Outcome = Data.define(:level, :message) do
      def to_s = "#{level}: #{message}"
    end

    def self.call(env = ENV) = new(env).call

    def initialize(env)
      @env = env
      @outcomes = []
    end

    def call
      spec = Spec.load(@env)
      spec.errors.each { error(it) }

      retire_servers(spec.declared.keys)
      spec.servers.each { provision_server(it, spec.declared.fetch(it.name)) }
      check_default_chat

      @outcomes
    rescue Spec::ParseError => e
      error("#{e.message}; leaving inference servers as they are")
      @outcomes
    end

    private

    def retire_servers(declared_names)
      InferenceServer.where(provisioned: true, enabled: true).where.not(name: declared_names).find_each do |server|
        InferenceServer.transaction do
          kept = server.inference_models.where(enabled: true).reject { disable_model(it) }
          next error("#{server.name} is no longer declared, but stays enabled for #{kept.map(&:name).to_sentence}") if kept.any?

          server.update!(enabled: false)
          warn("disabled #{server.name}: no longer declared")
        end
      end
    end

    def provision_server(entry, declared_models)
      server = InferenceServer.find_by(name: entry.name)
      return error("#{entry.name} conflicts with a server added in Settings, so it wasn't provisioned") if server && !server.provisioned?
      return error("#{entry.name} changed type; give it a new name to replace it") if server && !server.is_a?(entry.klass)

      server ||= entry.klass.new(name: entry.name, provisioned: true)
      created = server.new_record?

      InferenceServer.transaction do
        server.update!(**entry.attributes, enabled: true)
        server.inference_models.where(enabled: true).where.not(name: declared_models).find_each { disable_model(it) }
        entry.models.each { provision_model(server, it) }
      end
      info("#{created ? 'added' : 'updated'} #{server.name}") if created || server.saved_changes?
    rescue ActiveRecord::RecordInvalid => e
      error("#{entry.name} wasn't provisioned: #{e.record.errors.full_messages.to_sentence}")
    end

    def provision_model(server, entry)
      model = server.inference_models.find_or_initialize_by(name: entry.name)
      label = "#{server.name}/#{entry.name}"
      if model.persisted? && model.kind != entry.attributes[:kind]
        return error("#{label} changed kind; give it a new name to replace it")
      end
      if entry.attributes[:kind] == "chat" && !entry.attributes[:supports_tools]
        return error("#{label} can't call tools, so it can never search the archive; it wasn't provisioned")
      end

      InferenceModel.transaction(requires_new: true) do
        model.update!(**entry.attributes, provisioned: true, enabled: true)
      end
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      reason = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : e.message
      error("#{label} wasn't provisioned: #{reason}")
    end

    # Disabled rather than deleted, so conversations can still say which model
    # answered them; an admin can delete it afterwards.
    def disable_model(model)
      if model.embedding? && Embedding.exists?(embedding_model: model.name)
        error("#{model.name} is no longer declared, but the archive is embedded with it, so it stays enabled")
        return false
      end

      model.update!(enabled: false)
      warn("disabled #{model.inference_server.name}/#{model.name}: no longer declared")
      true
    end

    def check_default_chat
      raw = @env.fetch(Spec::DEFAULT_CHAT_VAR, nil)
      return if raw.blank?
      ref = Spec.default_chat_ref(@env)
      return error("#{Spec::DEFAULT_CHAT_VAR} must be \"server/model\"") if ref.nil?
      return if InferenceModel.pinned_default_chat(ref)

      error("#{Spec::DEFAULT_CHAT_VAR} names #{raw}, which isn't a usable chat model")
    end

    def info(message) = record(:info, message)
    def warn(message) = record(:warn, message)
    def error(message) = record(:error, message)

    def record(level, message)
      Rails.logger.public_send(level, "inference provisioning: #{message}")
      @outcomes << Outcome.new(level:, message:)
      nil
    end
  end
end
