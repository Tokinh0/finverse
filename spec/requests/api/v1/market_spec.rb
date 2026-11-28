require "rails_helper"

RSpec.describe "Api::V1::Market" do
  before do
    stub_awesomeapi
    stub_coingecko
    stub_bcb
  end

  it "returns the market overview" do
    get "/api/v1/market"

    expect(response).to have_http_status(:ok)
    expect(json["groups"].pluck("key")).to eq(%w[currencies crypto brazil])
    expect(json["brapi_configured"]).to be(false)
  end

  it "needs a signed-in profile" do
    get "/api/v1/market", headers: { "Authorization" => "" }

    expect(response).to have_http_status(:unauthorized)
  end

  describe "assets" do
    let!(:btc) { create(:asset, asset_type: "criptomoedas", ticker: "BTC", quantity: 2, current_value: 1) }

    it "values the profile's assets without saving" do
      get "/api/v1/market/assets"

      expect(json["assets"].first).to include("id" => btc.id, "status" => "priced", "live_value" => 660_000.0)
      expect(btc.reload.current_value).to eq(1)
    end

    it "leaves out other profiles' assets" do
      other = create(:profile)
      as_profile(other) { create(:asset, asset_type: "criptomoedas", ticker: "BTC") }

      get "/api/v1/market/assets"

      expect(json["assets"].pluck("id")).to eq([ btc.id ])
    end

    it "saves the live prices on request" do
      post "/api/v1/market/assets/apply", params: { asset_ids: [ btc.id ] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json["updated_count"]).to eq(1)
      expect(json["assets"].first["saved_value"]).to eq(660_000.0)
      expect(btc.reload.current_value).to eq(660_000)
    end
  end
end
