RSpec.shared_context "authenticated api client" do
  let(:client) { create(:client) }
  let(:headers) { { 'X-Client-Id' => client.client_id, 'Authorization' => "Bearer #{client.api_key}" } }
end
