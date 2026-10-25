# frozen_string_literal: true

# The mark and the name, as siblings: each caller supplies its own wrapper and
# sizing, and a blank name renders the mark alone. The triangle is square-ish
# and a logo needn't be, so each is sized by its own class.
class Views::BrandMark < Components::Base
  def initialize(mark_class: nil, logo_class: nil, name_class: nil, brand: Brand.current)
    @mark_class = mark_class
    @logo_class = logo_class
    @name_class = name_class
    @brand = brand
  end

  def view_template
    @brand.logo ? logo : mark
    span(class: @name_class) { @brand.name } if @brand.name.present?
  end

  private

  # Alt text only when it's all there is: beside the name, it would say it twice.
  def logo
    img(src: rails_blob_path(@brand.logo, only_path: true), class: @logo_class, alt: @brand.name.present? ? "" : "Logo")
  end

  def mark
    svg(viewbox: "0 0 24 20", class: @mark_class, aria_hidden: "true") do |s|
      s.polygon(points: "12,1 23,19 1,19", fill: "none", stroke: "#e6b455", stroke_width: "1.4")
      s.polygon(points: "12,7 17.5,17 6.5,17", fill: "none", stroke: "#e6b455", stroke_width: "0.8", opacity: "0.5")
    end
  end
end
