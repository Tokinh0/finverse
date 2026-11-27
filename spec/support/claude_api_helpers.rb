# Stubs for the Claude API. Real HTTP is blocked by WebMock, so specs never reach Anthropic.
module ClaudeApiHelpers
  CLAUDE_API = "https://api.anthropic.com".freeze

  def stub_claude_models(status: 200, body: { data: [], has_more: false, first_id: nil, last_id: nil })
    stub_request(:get, %r{\A#{CLAUDE_API}/v1/models})
      .to_return(status: status, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def claude_error_body(type, message = "error")
    { type: "error", error: { type: type, message: message } }
  end
end

RSpec.configure { |config| config.include ClaudeApiHelpers }
