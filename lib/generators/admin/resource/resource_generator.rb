# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"

module Admin
  # See USAGE. Everything below the `private` marker is a template helper, not a
  # step — Thor runs each public method of a generator as one.
  class ResourceGenerator < Rails::Generators::NamedBase
    source_root File.expand_path("templates", __dir__)

    LABELS = { "created_at" => "Created", "updated_at" => "Updated" }.freeze
    SCANNABLE = [:string, :integer, :float, :decimal, :boolean].freeze
    INDEX_COLUMN_LIMIT = 5

    class_option :namespace, type: :string, default: "settings",
      desc: "Controller, view and route namespace"
    class_option :columns, type: :array, default: [],
      desc: "Index table columns, in order (default: a guess from the schema)"
    class_option :destroy, type: :boolean, default: false,
      desc: "Add a destroy action and a Remove button"

    def create_controller
      template "controller.rb.tt", "app/controllers/#{namespace}/#{plural_name}_controller.rb"
    end

    def create_views
      template "index.rb.tt", "app/views/#{namespace}/#{plural_name}/index.rb"
      template "show.rb.tt", "app/views/#{namespace}/#{plural_name}/show.rb"
    end

    def create_spec
      template "request_spec.rb.tt", "spec/requests/#{namespace}/#{plural_name}_spec.rb"
    end

    def add_route
      if namespace_block?
        inject_into_file "config/routes.rb", "    #{resources_line}\n", after: "namespace :#{namespace} do\n"
      else
        route resources_line, namespace: namespace.to_sym
      end
    end

    def report
      say ""
      say "Now yours to finish:", :green
      say "  · the index blurb and the field labels — a reader gets told what these are, not what the columns are called"
      say "  · a card on the Admin page (app/views/settings/admin/index.rb) linking #{index_path_helper}"
      say "  · spec/factories/#{plural_name}.rb (the spec expects a :#{singular_name} factory)" unless factory?
      say ""
    end

    private

    def model_class
      @model_class ||= class_name.safe_constantize ||
        raise(Thor::Error, "There is no #{class_name} model. Pass the model's name, e.g. `ApiCall`.")
    end

    def namespace = options[:namespace]
    def namespace_module = namespace.camelize
    def view_module = "Views::#{namespace_module}::#{plural_name.camelize}"
    def controller_class = "#{plural_name.camelize}Controller"

    def title = human_name.pluralize
    def human_plural_down = title.downcase

    def actions = options[:destroy] ? "[:index, :show, :destroy]" : "[:index, :show]"
    def resources_line = "resources :#{plural_name}, only: #{actions}"

    def index_path_helper = "#{namespace}_#{plural_name}_path"
    def show_path_helper(record) = "#{namespace}_#{singular_name}_path(#{record})"

    def namespace_block?
      routes = File.expand_path("config/routes.rb", destination_root)
      File.exist?(routes) && File.read(routes).include?("namespace :#{namespace} do\n")
    end

    def factory? = File.exist?(File.expand_path("spec/factories/#{plural_name}.rb", destination_root))

    def timestamped? = model_class.column_names.include?("created_at")
    def default_order = timestamped? ? "order(created_at: :desc)" : "order(:id)"

    # The name a record goes by, for the breadcrumb and the detail heading.
    def title_expression
      titling = model_class.column_names.find { |name| ["name", "title"].include?(name) }
      return "@#{singular_name}.#{titling}" if titling

      %("#{human_name} ##{'#{'}@#{singular_name}.id}")
    end

    def index_fields = index_columns.map { |column| field(column, detail: false) }
    def detail_fields = columns_except_id.map { |column| field(column, detail: true) }

    def columns_except_id = model_class.columns.reject { |column| column.name == "id" }

    def index_columns
      return options[:columns].map { |name| column!(name) } if options[:columns].any?

      scannable = columns_except_id.select { |column| SCANNABLE.include?(column.type) }
      ordered = timestamped? ? [column!("created_at"), *scannable] : scannable
      ordered.first(INDEX_COLUMN_LIMIT)
    end

    def column!(name)
      model_class.columns.find { |column| column.name == name } ||
        raise(Thor::Error, "#{class_name} has no #{name} column.")
    end

    def field(column, detail:)
      %(Views::Admin::Field.new("#{label(column)}"#{field_options(column)}) { |record| #{cell(column, detail:)} })
    end

    def label(column) = LABELS.fetch(column.name, column.name.humanize)

    def field_options(column)
      case column.type
      when :integer, :float, :decimal then ", numeric: true"
      when :datetime then ", mono: true"
      else ""
      end
    end

    def cell(column, detail:)
      reader = "record.#{column.name}"

      case column.type
      when :datetime then "ago(#{reader})"
      when :boolean then "yes_no(#{reader})"
      when :integer, :float, :decimal then "count(#{reader})"
      when :json, :jsonb then detail ? "render Views::Admin::Json.new(value: #{reader})" : "yes_no(#{reader}.present?)"
      else detail ? "text(#{reader})" : "shortened(#{reader})"
      end
    end
  end
end
