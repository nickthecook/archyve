module Sources
  # Company files in picked categories of a BambooHR company, reached through an
  # Endpoints::Bamboohr.
  class Bamboohr < Source
    # Category ids: what was picked, never its expansion.
    store_accessor :config, :categories

    Catalogue = Data.define(:categories, :error)

    validates :categories, presence: true
    validate :categories_must_be_ids, if: -> { categories.present? }

    def self.endpoint_type = Endpoints::Bamboohr
    def self.supports_sync? = true
    def self.user_creatable? = true
    def self.filters_extensions? = true
    def self.type_label = "BambooHR"
    def self.form_component = Views::Sources::Forms::Bamboohr

    def self.description
      "Company files in categories you pick from BambooHR. Read, never written."
    end

    def location = endpoint&.host

    def categories=(value)
      super(Array(value).reject(&:blank?).map { |entry| entry.to_s.match?(/\A\d+\z/) ? entry.to_i : entry }.uniq)
    end

    def selected_categories = Array(categories)

    def catalogue(at: nil)
      return Catalogue.new(categories: [], error: nil) if endpoint.blank?

      Catalogue.new(categories: api.categories, error: nil)
    rescue StandardError => e
      Rails.logger.error("source #{id} could not list #{endpoint.name}: #{e.class}: #{e.message}")
      Catalogue.new(categories: [], error: "#{e.class}: #{e.message}")
    end

    def each_item(_run = nil)
      return enum_for(:each_item) unless block_given?

      api.categories.select { |category| selected_categories.include?(category.id) }.each do |category|
        category.files.each do |file|
          yield item_for(file, category) if eligible?(file)
        end
      end
    end

    def read(external_id) = api.read(external_id)

    # The stored name has no extension, and Docling picks its reader off one.
    def filename_for(document) = document.source_metadata["original_file_name"].presence || document.title

    private

    def api
      @api ||= endpoint.api
    end

    def eligible?(file)
      EXTRACTABLE_EXTENSIONS.include?(File.extname(file.original_file_name).downcase) && !file.size.zero?
    end

    # BambooHR reports no modification time, so creation time and size are the
    # best version token on offer. A file whose bytes change in place without
    # its size changing would go unnoticed.
    def item_for(file, category)
      Item.new(
        external_id: file.id,
        version: "#{file.created_at}:#{file.size}",
        title: file.name,
        content_type: Marcel::MimeType.for(name: file.original_file_name),
        byte_size: file.size,
        path: category.name,
        metadata: { "original_file_name" => file.original_file_name },
        skip_reason: size_skip_reason(file.size)
      )
    end

    def categories_must_be_ids
      return if selected_categories.all? { |category| category.is_a?(Integer) && category.positive? }

      errors.add(:categories, "must each be a BambooHR category id")
    end
  end
end
