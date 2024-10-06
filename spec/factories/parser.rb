FactoryBot.define do
  factory :parser, class: 'Parsers::Text' do
    doc { Nokogiri::HTML('') }
  end
end
