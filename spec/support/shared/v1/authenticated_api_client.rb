RSpec.shared_context "when api client is authenticated" do
  let(:client) { create(:client) }
  let(:headers) { { 'X-Client-Id' => client.client_id, 'Authorization' => "Bearer #{client.api_key}" } }
end
