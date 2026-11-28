require "rails_helper"

RSpec.describe "Api::V1::Settings::Market" do
  let(:token) { "brapi-secret-value-5678" }

  it "reports that no token is configured" do
    get "/api/v1/settings/market"

    expect(json).to eq("brapi_configured" => false, "masked_brapi_token" => nil, "brapi_from_env" => false)
  end

  it "saves a token for the account and returns only its masked form" do
    put "/api/v1/settings/market", params: { market: { brapi_token: " #{token} " } }

    expect(json).to include("brapi_configured" => true, "masked_brapi_token" => "…5678")
    expect(response.body).not_to include("secret")
    expect(AppSetting.current.brapi_token).to eq(token)
    expect(AppSetting.current.inspect).not_to include("secret")
  end

  it "rejects a blank token" do
    put "/api/v1/settings/market", params: { market: { brapi_token: " " } }

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "removes the token" do
    AppSetting.current.update!(brapi_token: token)

    delete "/api/v1/settings/market"

    expect(json["brapi_configured"]).to be(false)
    expect(AppSetting.current.reload.brapi_token).to be_nil
  end
end
