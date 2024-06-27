require 'rails_helper'

RSpec.describe Collection do
  subject { create(:collection, name: "Crazy Harry's Discount Documents") }

  describe "#generate_slug" do
    before do
      subject.generate_slug
    end

    it "generates a slug from the name" do
      expect(subject.slug).to eq("#{subject.id}-crazy-harry-s-discount-documents")
    end
  end
end
